///|
/// Low-level JSON-RPC method handler.
///
/// The argument is the request `params` member, or `None` when `params` is
/// absent. Return `Ok(result)` for a normal JSON-RPC result, or `Err(error)` to
/// send a JSON-RPC error response for calls with an id.
pub type Handler = (Json?) -> Result[Json, RpcError]

///|
/// JSON-RPC request id used for local request correlation.
pub(all) enum Id {
  String(String)
  Number(Int)
} derive(Eq, Hash, Debug)

///|
pub fn Id::to_json(self : Id) -> Json {
  match self {
    String(value) => Json::string(value)
    Number(value) => Json::number(value.to_double())
  }
}

///|
fn id_from_json(value : Json) -> Id? {
  match value {
    String(value) => Some(String(value))
    Number(value, ..) => {
      let int = value.to_int()
      if int.to_double() == value {
        Some(Number(int))
      } else {
        None
      }
    }
    _ => None
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
struct RequestError {
  id : Json?
  error : RpcError
} derive(Eq, Debug)

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
  { id, error: RpcError(invalid_request_code, "Invalid Request") }
}

///|
fn detect_id(obj : Map[String, Json]) -> Json? {
  match obj.get("id") {
    Some(id) => if is_valid_id(id) { Some(id) } else { None }
    None => None
  }
}

///|
/// Convert a JSON value to a validated request object.
fn parse_request(value : Json) -> Result[Request, RequestError] {
  guard value is Object(obj) else { return Err(request_error(None)) }
  let detected_id = detect_id(obj)
  guard obj.get("jsonrpc") is Some(String("2.0")) else {
    return Err(request_error(detected_id))
  }
  let rpc_method = match obj.get("method") {
    Some(String(name)) => name
    _ => return Err(request_error(detected_id))
  }
  let params = match obj.get("params") {
    None => None
    Some(Array(_) as params) => Some(params)
    Some(Object(_) as params) => Some(params)
    Some(_) => return Err(request_error(detected_id))
  }
  let id = match obj.get("id") {
    None => None
    Some(id) =>
      if is_valid_id(id) {
        Some(id)
      } else {
        return Err(request_error(None))
      }
  }
  Ok({ id, rpc_method, params, notification: id is None })
}

///|
fn success_response(id : Json, result : Json) -> Json {
  let obj : Map[String, Json] = {}
  obj["jsonrpc"] = Json::string("2.0")
  obj["result"] = result
  obj["id"] = id
  Json::object(obj)
}

///|
fn error_response(id : Json, error : RpcError) -> Json {
  let obj : Map[String, Json] = {}
  obj["jsonrpc"] = Json::string("2.0")
  obj["error"] = error.to_json()
  obj["id"] = id
  Json::object(obj)
}

///|
fn unknown_id_error(error : RpcError) -> Json {
  error_response(null, error)
}

///|
struct Response {
  id : Json
  result : Result[Json, RpcError]
} derive(Eq, Debug)

///|
fn parse_response(value : Json) -> Response? {
  guard value is Object(obj) else { return None }
  guard obj.get("jsonrpc") is Some(String("2.0")) else { return None }
  let id = match obj.get("id") {
    Some(value) => value
    None => return None
  }
  match (obj.get("result"), obj.get("error")) {
    (Some(result), None) => Some({ id, result: Ok(result) })
    (None, Some(error_json)) =>
      match rpc_error_from_json(error_json) {
        Some(error) => Some({ id, result: Err(error) })
        None => None
      }
    _ => None
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
