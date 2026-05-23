///|
/// JSON-RPC 2.0 error code for parse failures.
pub const PARSE_ERROR_CODE : Int = -32700

///|
/// JSON-RPC 2.0 error code for structurally invalid requests.
pub const INVALID_REQUEST_CODE : Int = -32600

///|
/// JSON-RPC 2.0 error code for unknown methods.
pub const METHOD_NOT_FOUND_CODE : Int = -32601

///|
/// JSON-RPC 2.0 error code for invalid method parameters.
pub const INVALID_PARAMS_CODE : Int = -32602

///|
/// JSON-RPC 2.0 error code for unexpected server failures.
pub const INTERNAL_ERROR_CODE : Int = -32603

///|
/// Error returned by a method handler.
pub(all) suberror RpcError {
  RpcError(code~ : Int, message~ : String)
  RpcErrorWithData(code~ : Int, message~ : String, data~ : Json)
} derive(Eq, Debug)

///|
/// Standard "Invalid params" error.
pub fn invalid_params(message? : String = "Invalid params") -> RpcError {
  RpcError(code=INVALID_PARAMS_CODE, message~)
}

///|
/// Standard "Internal error" error.
pub fn internal_error(message? : String = "Internal error") -> RpcError {
  RpcError(code=INTERNAL_ERROR_CODE, message~)
}

///|
/// Convert an error to the JSON-RPC error object shape.
pub fn RpcError::to_json(self : RpcError) -> Json {
  let (code, message, data) = match self {
    RpcError(code~, message~) => (code, message, None)
    RpcErrorWithData(code~, message~, data~) => (code, message, Some(data))
  }
  let obj : Map[String, Json] = {}
  obj["code"] = Json::number(code.to_double())
  obj["message"] = Json::string(message)
  if data is Some(data) {
    obj["data"] = data
  }
  Json::object(obj)
}

///|
fn rpc_error_from_json(value : Json) -> RpcError? {
  guard value is Object(obj) else { return None }
  let code = match obj.get("code") {
    Some(Number(value, ..)) => value.to_int()
    _ => return None
  }
  let message = match obj.get("message") {
    Some(String(value)) => value
    _ => return None
  }
  Some(
    match obj.get("data") {
      Some(data) => RpcErrorWithData(code~, message~, data~)
      None => RpcError(code~, message~)
    },
  )
}

///|
pub(all) enum EndpointError {
  DuplicatePendingId(Id)
  DuplicateMethod(String)
  ReservedMethod(String)
  InvalidMethod(String)
} derive(Eq, Debug)
