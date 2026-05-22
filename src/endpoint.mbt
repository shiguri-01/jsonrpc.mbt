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
  run : (P) -> Result[R, RpcError],
) -> Handler {
  params => {
    let decoded : P = match decode_params(params) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match run(decoded) {
      Ok(result) => Ok(result.to_json())
      Err(error) => Err(error)
    }
  }
}

///|
fn[P : @json.FromJson] decode_params(params : Json?) -> Result[P, RpcError] {
  let value = params.unwrap_or(null)
  let decoded : P = @json.from_json(value) catch {
    JsonDecodeError((path, message)) => {
      let data : Map[String, Json] = {}
      data["path"] = path.to_json()
      data["message"] = Json::string(message)
      return Err(
        RpcError(invalid_params_code, "Invalid params", data=Json::object(data)),
      )
    }
  }
  Ok(decoded)
}

///|
fn validate_method_name(name : String) -> EndpointError? {
  if name == "" {
    Some(InvalidMethod(name))
  } else if name.has_prefix("rpc.") {
    Some(ReservedMethod(name))
  } else {
    None
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
  if validate_method_name(name) is Some(error) {
    errors.push(error)
    return { handlers, errors }
  }
  if self.handlers.get(name) is Some(_) {
    errors.push(DuplicateMethod(name))
    return { handlers, errors }
  }
  handlers[name] = handler
  { handlers, errors }
}

///|
/// Build the runtime endpoint.
pub fn EndpointBuilder::build(
  self : EndpointBuilder,
) -> Result[Endpoint, EndpointError] {
  if self.errors.get(0) is Some(error) {
    Err(error)
  } else {
    Ok({ router: self.handlers, next_id: 1, pending: {} })
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
fn make_request_message(rpc_method : String, params : Json?, id : Id?) -> Json {
  let obj : Map[String, Json] = {}
  obj["jsonrpc"] = Json::string("2.0")
  obj["method"] = Json::string(rpc_method)
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
) -> Result[Json, EndpointError] {
  if validate_method_name(rpc_method) is Some(error) {
    return Err(error)
  }
  let request_id = match id {
    Some(value) => value
    None => self.allocate_id()
  }
  if self.pending.get(request_id) is Some(_) {
    return Err(DuplicatePendingId(request_id))
  }
  self.pending[request_id] = { name: rpc_method }
  Ok(make_request_message(rpc_method, params, Some(request_id)))
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
) -> Result[Json, EndpointError] {
  if validate_method_name(rpc_method) is Some(error) {
    return Err(error)
  }
  Ok(make_request_message(rpc_method, params, None))
}

///|
/// Handle a raw JSON document.
pub fn Endpoint::receive_text(self : Endpoint, input : String) -> ReceiveResult {
  let value = @json.parse(input) catch {
    _ =>
      return {
        outgoing: [unknown_id_error(RpcError(parse_error_code, "Parse error"))],
        completed: [],
        unexpected: [],
      }
  }
  self.receive_json(value)
}

///|
/// Handle an already parsed JSON value.
pub fn Endpoint::receive_json(self : Endpoint, value : Json) -> ReceiveResult {
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
fn Endpoint::receive_batch(
  self : Endpoint,
  items : Array[Json],
  result : ReceiveResult,
) -> ReceiveResult {
  if items.is_empty() {
    result.outgoing.push(
      unknown_id_error(RpcError(invalid_request_code, "Invalid Request")),
    )
    return result
  }
  for item in items {
    self.receive_one(item, result)
  }
  result
}

///|
fn Endpoint::receive_one(
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
fn Endpoint::receive_request_like(
  self : Endpoint,
  value : Json,
  result : ReceiveResult,
) -> Unit {
  let request = match parse_request(value) {
    Ok(request) => request
    Err(error) =>
      return result.outgoing.push(
        error_response(error.id.unwrap_or(null), error.error),
      )
  }
  let id = request.id.unwrap_or(null)
  let handler = match self.router.get(request.rpc_method) {
    Some(handler) => handler
    None =>
      if request.notification {
        return
      } else {
        return result.outgoing.push(
          error_response(
            id,
            RpcError(method_not_found_code, "Method not found"),
          ),
        )
      }
  }
  match handler(request.params) {
    Ok(json_result) =>
      if request.notification {
        ()
      } else {
        result.outgoing.push(success_response(id, json_result))
      }
    Err(error) =>
      if request.notification {
        ()
      } else {
        result.outgoing.push(error_response(id, error))
      }
  }
}

///|
fn Endpoint::receive_response_like(
  self : Endpoint,
  value : Json,
  result : ReceiveResult,
) -> Unit {
  match parse_response(value) {
    Some(response) => self.complete_response(response, value, result)
    None => result.unexpected.push(value)
  }
}

///|
fn Endpoint::complete_response(
  self : Endpoint,
  response : Response,
  raw : Json,
  result : ReceiveResult,
) -> Unit {
  match id_from_json(response.id) {
    Some(id) =>
      match self.pending.get(id) {
        Some(pending) => {
          self.pending.remove(id)
          result.completed.push({
            id,
            method_name: pending.name,
            result: response.result,
          })
        }
        None => result.unexpected.push(raw)
      }
    None => result.unexpected.push(raw)
  }
}
