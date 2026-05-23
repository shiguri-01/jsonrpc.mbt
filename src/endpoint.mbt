///|
/// Builder for a JSON-RPC endpoint method table.
pub struct EndpointBuilder {
  priv handlers : Map[String, Handler]
  priv errors : Array[EndpointError]
}

///|
/// Create an empty endpoint builder.
pub fn EndpointBuilder::EndpointBuilder() -> EndpointBuilder {
  { handlers: {}, errors: [] }
}

///|
pub fn[P : @json.FromJson, R : ToJson] typed(
  run : async (P) -> R raise RpcError,
) -> Handler {
  async fn(params) -> Json raise RpcError {
    let decoded : P = decode_params(params)
    run(decoded).to_json()
  }
}

///|
fn[P : @json.FromJson] decode_params(params : Json?) -> P raise RpcError {
  let value = params.unwrap_or(null)
  @json.from_json(value) catch {
    JsonDecodeError((path, message)) => {
      let data : Map[String, Json] = {
        "path": path.to_json(),
        "message": Json::string(message),
      }
      raise RpcErrorWithData(
        code=INVALID_PARAMS_CODE,
        message="Invalid params",
        data=Json::object(data),
      )
    }
  }
}

///|
fn validate_method_name(name : String) -> Unit raise EndpointError {
  if name == "" {
    raise InvalidMethod(name)
  } else if name.has_prefix("rpc.") {
    raise ReservedMethod(name)
  }
}

///|
pub fn EndpointBuilder::handle(
  self : EndpointBuilder,
  name : String,
  handler : Handler,
) -> EndpointBuilder {
  let handlers = self.handlers.copy()
  let errors = self.errors.copy()
  try validate_method_name(name) catch {
    error => errors.push(error)
  } noraise {
    _ if self.handlers.get(name) is Some(_) =>
      errors.push(DuplicateMethod(name))
    _ => handlers[name] = handler
  }
  { handlers, errors }
}

///|
/// Build the runtime endpoint.
pub fn EndpointBuilder::build(
  self : EndpointBuilder,
) -> Endpoint raise EndpointError {
  match self.errors {
    [error, ..] => raise error
    [] => { router: self.handlers, next_id: 1, pending: {} }
  }
}

///|
struct Pending {
  name : String
} derive(Eq, Debug)

///|
/// One side of a JSON-RPC connection.
pub struct Endpoint {
  priv router : Map[String, Handler]
  priv mut next_id : Int
  priv pending : Map[Id, Pending]
}

///|
fn make_request_message(rpc_method : String, params? : Json, id? : Id) -> Json {
  let obj : Map[String, Json] = {
    "jsonrpc": "2.0",
    "method": Json::string(rpc_method),
  }
  if params is Some(value) {
    obj["params"] = value
  }
  if id is Some(value) {
    obj["id"] = value.to_json()
  }
  Json::object(obj)
}

///|
pub fn Endpoint::request(
  self : Endpoint,
  rpc_method : String,
  params? : Json,
  id? : Id,
) -> Json raise EndpointError {
  validate_method_name(rpc_method)
  let request_id = match id {
    Some(value) => value
    None => self.allocate_id()
  }
  guard self.pending.get(request_id) is None else {
    raise DuplicatePendingId(request_id)
  }
  self.pending[request_id] = { name: rpc_method }
  make_request_message(rpc_method, params?, id=request_id)
}

///|
fn Endpoint::allocate_id(self : Endpoint) -> Id {
  let mut value = Number(self.next_id)
  while self.pending.get(value) is Some(_) {
    self.next_id = self.next_id + 1
    value = Number(self.next_id)
  }
  self.next_id = self.next_id + 1
  value
}

///|
pub fn Endpoint::notify(
  _self : Endpoint,
  rpc_method : String,
  params? : Json,
) -> Json raise EndpointError {
  validate_method_name(rpc_method)
  make_request_message(rpc_method, params?)
}

///|
/// Handle a raw JSON document.
pub async fn Endpoint::receive_text(
  self : Endpoint,
  input : String,
) -> ReceiveResult {
  try @json.parse(input) catch {
    _ =>
      {
        outgoing: [
          unknown_id_error(
            RpcError(code=PARSE_ERROR_CODE, message="Parse error"),
          ),
        ],
        completed: [],
        unexpected: [],
      }
  } noraise {
    value => self.receive_json(value)
  }
}

///|
/// Handle an already parsed JSON value.
pub async fn Endpoint::receive_json(
  self : Endpoint,
  value : Json,
) -> ReceiveResult {
  let result = ReceiveResult()
  match value {
    Array(items) => self.receive_batch(items, result)
    item => {
      self.receive_one(item, result)
      result
    }
  }
}

///|
async fn Endpoint::receive_batch(
  self : Endpoint,
  items : Array[Json],
  result : ReceiveResult,
) -> ReceiveResult {
  if items.is_empty() {
    result.outgoing.push(
      unknown_id_error(
        RpcError(code=INVALID_REQUEST_CODE, message="Invalid Request"),
      ),
    )
  } else {
    for item in items {
      self.receive_one(item, result)
    }
  }
  result
}

///|
async fn Endpoint::receive_one(
  self : Endpoint,
  value : Json,
  result : ReceiveResult,
) -> Unit {
  match classify_message(value) {
    RequestLike => self.receive_request_like(value, result)
    ResponseLike => self.receive_response_like(value, result)
    InvalidLike => self.receive_request_like(value, result)
  }
}

///|
async fn Endpoint::receive_request_like(
  self : Endpoint,
  value : Json,
  result : ReceiveResult,
) -> Unit {
  try parse_request(value) catch {
    RequestError(error~, ..) as request_error =>
      result.outgoing.push(error_response(request_error.response_id(), error))
  } noraise {
    request => self.receive_request(request, result)
  }
}

///|
async fn Endpoint::receive_request(
  self : Endpoint,
  request : Request,
  result : ReceiveResult,
) -> Unit {
  let response_id = request.response_id()
  guard self.router.get(request.rpc_method) is Some(handler) else {
    if !request.notification {
      result.outgoing.push(
        error_response(
          response_id,
          RpcError(code=METHOD_NOT_FOUND_CODE, message="Method not found"),
        ),
      )
    }
  }
  try handler(request.params) catch {
    error =>
      if !request.notification {
        result.outgoing.push(error_response(response_id, error))
      }
  } noraise {
    json_result =>
      if !request.notification {
        result.outgoing.push(success_response(response_id, json_result))
      }
  }
}

///|
fn Endpoint::receive_response_like(
  self : Endpoint,
  value : Json,
  result : ReceiveResult,
) -> Unit {
  try @json.from_json(value) catch {
    _ => result.unexpected.push(value)
  } noraise {
    response => self.complete_response(response, value, result)
  }
}

///|
fn Endpoint::complete_response(
  self : Endpoint,
  response : Response,
  raw : Json,
  result : ReceiveResult,
) -> Unit {
  try @json.from_json(response.id) catch {
    _ => result.unexpected.push(raw)
  } noraise {
    id => {
      guard self.pending.get(id) is Some(pending) else {
        result.unexpected.push(raw)
      }
      self.pending.remove(id)
      result.completed.push({
        id,
        method_name: pending.name,
        result: response.result,
      })
    }
  }
}
