///|
/// Low-level JSON-RPC method handler.
///
/// The argument is the request `params` member, or `None` when `params` is
/// absent. Return a JSON-RPC result value, or raise `RpcError` to send a
/// JSON-RPC error response for calls with an id.
pub type Handler = async (Json?) -> Json raise RpcError

///|
/// JSON-RPC request id used for local request correlation.
pub(all) enum Id {
  String(String)
  Number(Int)
} derive(Eq, Hash, Debug)

///|
pub impl ToJson for Id with to_json(self) {
  match self {
    String(value) => Json::string(value)
    Number(value) => Json::number(value.to_double())
  }
}

///|
pub impl @json.FromJson for Id with from_json(value, path) {
  match value {
    String(value) => String(value)
    Number(value, ..) => {
      let int = value.to_int()
      guard int.to_double() == value else {
        raise JsonDecodeError((path, "Id::from_json: expected integer id"))
      }
      Number(int)
    }
    _ =>
      raise JsonDecodeError((path, "Id::from_json: expected string or number"))
  }
}

///|
/// Parsed request data used internally by the dispatcher.
struct Request {
  id : Json?
  rpc_method : String
  params : Json?
  notification : Bool
} derive(Eq, Debug)

///|
/// Request parsing failure plus any valid id that could still be detected.
suberror RequestError {
  RequestError(id~ : Json?, error~ : RpcError)
} derive(Eq, Debug)

///|
fn Request::response_id(self : Request) -> Json {
  self.id.unwrap_or(null)
}

///|
fn RequestError::response_id(self : RequestError) -> Json {
  match self {
    RequestError(id~, ..) => id.unwrap_or(null)
  }
}

///|
/// Return true when a JSON value is a legal JSON-RPC request id.
fn is_valid_id(value : Json) -> Bool {
  match value {
    String(_) | Number(_, ..) | Null => true
    _ => false
  }
}

///|
fn request_error(id : Json?) -> RequestError {
  RequestError(
    id~,
    error=RpcError(code=INVALID_REQUEST_CODE, message="Invalid Request"),
  )
}

///|
fn detect_id(obj : Map[String, Json]) -> Json? {
  guard obj is { "id": id, .. } else { None }
  guard is_valid_id(id) else { None }
  Some(id)
}

///|
/// Convert a JSON value to a validated request object.
fn parse_request(value : Json) -> Request raise RequestError {
  guard value is Object(obj) else { raise request_error(None) }
  let detected_id = detect_id(obj)
  guard obj is { "jsonrpc": String("2.0"), "method": String(rpc_method), .. } else {
    raise request_error(detected_id)
  }
  let params = match obj {
    { "params": Array(_) | Object(_) as params, .. } => Some(params)
    { "params": _, .. } => raise request_error(detected_id)
    _ => None
  }
  let id = match obj {
    { "id": id, .. } if is_valid_id(id) => Some(id)
    { "id": _, .. } => raise request_error(None)
    _ => None
  }
  { id, rpc_method, params, notification: id is None }
}

///|
fn success_response(id : Json, result : Json) -> Json {
  let response : Response = { id, result: Ok(result) }
  response.to_json()
}

///|
fn error_response(id : Json, error : RpcError) -> Json {
  let response : Response = { id, result: Err(error) }
  response.to_json()
}

///|
fn unknown_id_error(error : RpcError) -> Json {
  error_response(null, error)
}

///|
enum MessageKind {
  RequestLike
  ResponseLike
  InvalidLike
} derive(Eq, Debug)

///|
fn classify_message(value : Json) -> MessageKind {
  match value {
    Object({ "method": _, .. }) => RequestLike
    Object({ "result": _, .. }) | Object({ "error": _, .. }) => ResponseLike
    _ => InvalidLike
  }
}

///|
struct Response {
  id : Json
  result : Result[Json, RpcError]
} derive(Eq, Debug)

///|
impl ToJson for Response with to_json(self) {
  let obj : Map[String, Json] = { "jsonrpc": "2.0", "id": self.id }
  match self.result {
    Ok(result) => obj["result"] = result
    Err(error) => obj["error"] = error.to_json()
  }
  Json::object(obj)
}

///|
impl @json.FromJson for Response with from_json(value, path) {
  match value {
    Object({ "jsonrpc": String("2.0"), "id": _, "result": _, "error": _, .. }) =>
      raise JsonDecodeError(
        (path, "Response::from_json: result and error are mutually exclusive"),
      )
    Object({ "jsonrpc": String("2.0"), "id": id, "result": result, .. }) =>
      { id, result: Ok(result) }
    Object({ "jsonrpc": String("2.0"), "id": id, "error": error_json, .. }) => {
      let error : RpcError = @json.from_json(error_json, path~)
      { id, result: Err(error) }
    }
    _ =>
      raise JsonDecodeError(
        (path, "Response::from_json: expected response object"),
      )
  }
}

///|
pub(all) struct CompletedRequest {
  id : Id
  method_name : String
  result : Result[Json, RpcError]
} derive(Eq, Debug)

///|
pub(all) struct ReceiveResult {
  outgoing : Array[Json]
  completed : Array[CompletedRequest]
  unexpected : Array[Json]
} derive(Eq, Debug)

///|
fn ReceiveResult::ReceiveResult() -> ReceiveResult {
  { outgoing: [], completed: [], unexpected: [] }
}

///|
pub fn batch(items : Array[Json]) -> Json {
  Json::array(items)
}
