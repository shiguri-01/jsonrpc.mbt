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
/// Construct an RPC error without extra data.
pub fn RpcError::new(code : Int, message : String) -> RpcError {
  { code, message, data: None }
}

///|
/// Construct an RPC error with additional JSON data.
pub fn RpcError::with_data(
  code : Int,
  message : String,
  data : Json,
) -> RpcError {
  { code, message, data: Some(data) }
}

///|
/// Standard "Invalid params" error.
pub fn invalid_params(message? : String = "Invalid params") -> RpcError {
  RpcError::new(invalid_params_code, message)
}

///|
/// Standard "Internal error" error.
pub fn internal_error(message? : String = "Internal error") -> RpcError {
  RpcError::new(internal_error_code, message)
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
