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
pub impl ToJson for RpcError with fn to_json(self) {
  let (code, message, data) = match self {
    RpcError(code~, message~) => (code, message, None)
    RpcErrorWithData(code~, message~, data~) => (code, message, Some(data))
  }
  let obj : Map[String, Json] = {
    "code": Json::number(code.to_double()),
    "message": Json::string(message),
  }
  if data is Some(data) {
    obj["data"] = data
  }
  Json::object(obj)
}

///|
fn decode_integer(
  value : Double,
  path : @json.JsonPath,
  name : String,
) -> Int raise @json.JsonDecodeError {
  let int = value.to_int()
  guard int.to_double() == value else {
    raise JsonDecodeError((path, "\{name}: expected integer"))
  }
  int
}

///|
pub impl @json.FromJson for RpcError with fn from_json(value, path) {
  match value {
    Object(
      {
        "code": Number(code_value, ..),
        "message": String(message),
        "data": data,
        ..
      }
    ) => {
      let code = decode_integer(
        code_value,
        path.add_key("code"),
        "RpcError::from_json",
      )
      RpcErrorWithData(code~, message~, data~)
    }
    Object({ "code": Number(code_value, ..), "message": String(message), .. }) => {
      let code = decode_integer(
        code_value,
        path.add_key("code"),
        "RpcError::from_json",
      )
      RpcError(code~, message~)
    }
    _ =>
      raise JsonDecodeError(
        (path, "RpcError::from_json: expected error object"),
      )
  }
}

///|
/// Error raised while constructing local requests or endpoint method tables.
pub(all) suberror EndpointError {
  DuplicatePendingId(Id)
  DuplicateMethod(String)
  ReservedMethod(String)
  InvalidMethod(String)
} derive(Eq, Debug)
