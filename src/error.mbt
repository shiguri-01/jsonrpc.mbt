///|
/// JSON-RPC 2.0 error code for parse failures.
pub let parse_error_code : Int = -32700

///|
/// JSON-RPC 2.0 error code for structurally invalid requests.
pub let invalid_request_code : Int = -32600

///|
/// JSON-RPC 2.0 error code for unknown methods.
pub let method_not_found_code : Int = -32601

///|
/// JSON-RPC 2.0 error code for invalid method parameters.
pub let invalid_params_code : Int = -32602

///|
/// JSON-RPC 2.0 error code for unexpected server failures.
pub let internal_error_code : Int = -32603

///|
/// Error returned by a method handler.
pub(all) struct RpcError {
  code : Int
  message : String
  data : Json?
} derive(Eq, Debug)

///|
/// Construct an RPC error value.
pub fn RpcError::RpcError(
  code : Int,
  message : String,
  data? : Json,
) -> RpcError {
  { code, message, data }
}

///|
/// Standard "Invalid params" error.
pub fn invalid_params(message? : String = "Invalid params") -> RpcError {
  RpcError(invalid_params_code, message)
}

///|
/// Standard "Internal error" error.
pub fn internal_error(message? : String = "Internal error") -> RpcError {
  RpcError(internal_error_code, message)
}

///|
/// Convert an error to the JSON-RPC error object shape.
pub fn RpcError::to_json(self : RpcError) -> Json {
  let obj : Map[String, Json] = {}
  obj["code"] = Json::number(self.code.to_double())
  obj["message"] = Json::string(self.message)
  if self.data is Some(data) {
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
      Some(data) => RpcError(code, message, data~)
      None => RpcError(code, message)
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
