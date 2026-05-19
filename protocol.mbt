///|
type Handler = (Json?) -> Result[Json, RpcError]

///|
/// Parsed request data used internally by the dispatcher.
struct Request {
  id : Json?
  rpc_method : String
  params : Json?
  notification : Bool
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
/// Convert a JSON value to a validated request object.
fn parse_request(value : Json) -> Result[Request, RpcError] {
  guard value is Object(obj) else {
    return Err(RpcError::new(invalid_request_code, "Invalid Request"))
  }
  guard obj.get("jsonrpc") is Some(String("2.0")) else {
    return Err(RpcError::new(invalid_request_code, "Invalid Request"))
  }
  let rpc_method = match obj.get("method") {
    Some(String(name)) => name
    _ => return Err(RpcError::new(invalid_request_code, "Invalid Request"))
  }
  let params = match obj.get("params") {
    None => None
    Some(Array(_) as params) => Some(params)
    Some(Object(_) as params) => Some(params)
    Some(_) =>
      return Err(RpcError::new(invalid_request_code, "Invalid Request"))
  }
  let id = match obj.get("id") {
    None => None
    Some(id) =>
      if is_valid_id(id) {
        Some(id)
      } else {
        return Err(RpcError::new(invalid_request_code, "Invalid Request"))
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
