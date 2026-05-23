///|
#warnings("-67")
async fn response_json(endpoint : Endpoint, input : String) -> Json {
  let result = endpoint.receive_text(input)
  guard result.outgoing is [response] else {
    fail("expected one outgoing response")
  }
  response
}

///|
#warnings("-73")
struct AddParams {
  left : Int
  right : Int
} derive(FromJson, Eq, Debug)

///|
struct AddResult {
  value : Int
} derive(ToJson)

///|
#warnings("-67-24")
async fn add(params : AddParams) -> AddResult raise RpcError {
  { value: params.left + params.right }
}

///|
#warnings("-67-24")
async fn add_tuple(params : (Int, Int)) -> Int raise RpcError {
  let (left, right) = params
  left + right
}

///|
#warnings("-67-24")
async fn ping(_params : Unit) -> String raise RpcError {
  "pong"
}

///|
#warnings("-67")
async fn add_handler(params : Json?) -> Json raise RpcError {
  match params {
    Some(Array([Number(a, ..), Number(b, ..)])) => Json::number(a + b)
    _ => raise invalid_params()
  }
}

///|
#warnings("-67")
async fn subtract_handler(params : Json?) -> Json raise RpcError {
  match params {
    Some(Array([Number(minuend, ..), Number(subtrahend, ..)])) =>
      Json::number(minuend - subtrahend)
    Some(
      Object(
        {
          "minuend": Number(minuend, ..),
          "subtrahend": Number(subtrahend, ..),
          ..
        }
      )
    ) => Json::number(minuend - subtrahend)
    _ => raise invalid_params()
  }
}

///|
#warnings("-67-24")
async fn ok_null(_params : Json?) -> Json raise RpcError {
  null
}

///|
#warnings("-67")
async fn unavailable(_params : Json?) -> Json raise RpcError {
  raise RpcErrorWithData(
    code=-32042,
    message="Temporarily unavailable",
    data="retry later",
  )
}

///|
fn test_endpoint() -> Endpoint raise EndpointError {
  @jsonrpc.EndpointBuilder()
  .handle("add", add_handler)
  .handle("subtract", subtract_handler)
  .handle("update", ok_null)
  .handle("unavailable", unavailable)
  .build()
}

///|
fn assert_error_code(response : Json, code : Double) -> Unit raise {
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(actual, ..)) else {
    fail("unexpected error code")
  }
  guard actual == code else { fail("unexpected error code") }
}

///|
async test "builder registers raw and typed handlers" {
  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("add", typed(add))
    .handle("tuple/add", typed(add_tuple))
    .handle("ping", typed(ping))
    .build()
  let object_call =
    #|{"jsonrpc":"2.0","method":"add","params":{"left":2,"right":3},"id":1}
  let object_response = response_json(endpoint, object_call)
  guard object_response is Object(object) else {
    fail("response must be object")
  }
  guard object.get("result") is Some(Object(result)) else {
    fail("result must be object")
  }
  guard result.get("value") is Some(Number(5.0, ..)) else {
    fail("result value must be 5")
  }

  let tuple_call =
    #|{"jsonrpc":"2.0","method":"tuple/add","params":[2,3],"id":2}
  let tuple_response = response_json(endpoint, tuple_call)
  guard tuple_response is Object(tuple) else { fail("response must be object") }
  guard tuple.get("result") is Some(Number(5.0, ..)) else {
    fail("tuple result must be 5")
  }

  let unit_call =
    #|{"jsonrpc":"2.0","method":"ping","id":3}
  let unit_response = response_json(endpoint, unit_call)
  guard unit_response is Object(unit_obj) else {
    fail("response must be object")
  }
  guard unit_obj.get("result") is Some(String("pong")) else {
    fail("unit result must be pong")
  }
}

///|
async test "typed decode failures become invalid params" {
  let endpoint = @jsonrpc.EndpointBuilder().handle("add", typed(add)).build()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":{"left":"two","right":3},"id":1}
  let response = response_json(endpoint, request)
  assert_error_code(response, INVALID_PARAMS_CODE.to_double())
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("must include error")
  }
  guard error.get("data") is Some(Object(data)) else {
    fail("decode error must include data")
  }
  guard data.get("path") is Some(String("/left")) else {
    fail("decode path must identify the bad field")
  }
}

///|
async test "notification produces no outgoing response" {
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3]}
  let result = test_endpoint().receive_text(request)
  guard result.outgoing.is_empty() else {
    fail("notification must not respond")
  }
  guard result.completed.is_empty() else {
    fail("notification must not complete")
  }
}

///|
async test "notification errors are suppressed" {
  let handler_error =
    #|{"jsonrpc":"2.0","method":"unavailable"}
  let handler_result = test_endpoint().receive_text(handler_error)
  guard handler_result.outgoing.is_empty() else {
    fail("notification handler error must not respond")
  }
  guard handler_result.completed.is_empty() else {
    fail("notification handler error must not complete")
  }

  let missing_method =
    #|{"jsonrpc":"2.0","method":"missing"}
  let missing_result = test_endpoint().receive_text(missing_method)
  guard missing_result.outgoing.is_empty() else {
    fail("missing notification method must not respond")
  }
}

///|
async test "request id null is preserved for incoming calls" {
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":null}
  let response = response_json(test_endpoint(), request)
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("result must be 5")
  }
  guard obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
async test "method not found and parse errors are protocol errors" {
  let endpoint = test_endpoint()
  let missing_request =
    #|{"jsonrpc":"2.0","method":"missing","id":"x"}
  let missing = response_json(endpoint, missing_request)
  assert_error_code(missing, METHOD_NOT_FOUND_CODE.to_double())
  guard missing is Object(missing_obj) else { fail("response must be object") }
  guard missing_obj.get("id") is Some(String("x")) else {
    fail("id must be preserved")
  }

  let parse_error = response_json(endpoint, "{\"jsonrpc\":")
  assert_error_code(parse_error, PARSE_ERROR_CODE.to_double())
  guard parse_error is Object(parse_obj) else {
    fail("response must be object")
  }
  guard parse_obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
async test "invalid request preserves valid id" {
  let invalid_with_id =
    #|{"jsonrpc":"2.0","params":[],"id":"x"}
  let response = response_json(test_endpoint(), invalid_with_id)
  assert_error_code(response, INVALID_REQUEST_CODE.to_double())
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("id") is Some(String("x")) else {
    fail("valid id must be preserved")
  }
}

///|
async test "invalid request with invalid id responds with null id" {
  let invalid_id =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":[]}
  let response = response_json(test_endpoint(), invalid_id)
  assert_error_code(response, INVALID_REQUEST_CODE.to_double())
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("id") is Some(Null) else {
    fail("invalid id must not be preserved")
  }
}

///|
async test "scalar params are invalid request" {
  let scalar_params =
    #|{"jsonrpc":"2.0","method":"add","params":1,"id":1}
  let response = response_json(test_endpoint(), scalar_params)
  assert_error_code(response, INVALID_REQUEST_CODE.to_double())
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("id") is Some(Number(1.0, ..)) else {
    fail("id must be preserved for scalar params error")
  }
}

///|
async test "batch receive accumulates outgoing messages in order" {
  let request =
    #|[
    #|  {"jsonrpc":"2.0","method":"subtract","params":[42,23],"id":1},
    #|  {"jsonrpc":"2.0","method":"update","params":[1,2,3]},
    #|  {"foo":"boo"},
    #|  {"jsonrpc":"2.0","method":"subtract","params":{"minuend":23,"subtrahend":42},"id":2}
    #|]
  let result = test_endpoint().receive_text(request)
  guard result.outgoing.length() == 3 else {
    fail("batch must include call and invalid request responses")
  }
  guard result.outgoing[0] is Object(first) else {
    fail("first must be object")
  }
  guard first.get("result") is Some(Number(19.0, ..)) else {
    fail("first result must be 19")
  }
  assert_error_code(result.outgoing[1], INVALID_REQUEST_CODE.to_double())
  guard result.outgoing[2] is Object(last) else { fail("last must be object") }
  guard last.get("result") is Some(Number(-19.0, ..)) else {
    fail("last result must be -19")
  }
}

///|
async test "empty batch returns invalid request response" {
  let response = response_json(test_endpoint(), "[]")
  assert_error_code(response, INVALID_REQUEST_CODE.to_double())
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
async test "outgoing request auto id and completion" {
  let endpoint = test_endpoint()
  let request = endpoint.request("remote/add", params=[2])
  guard request is Object(obj) else { fail("request must be object") }
  guard obj.get("id") is Some(Number(1.0, ..)) else { fail("id must be 1") }

  let response =
    #|{"jsonrpc":"2.0","result":{"value":5},"id":1}
  let result = endpoint.receive_text(response)
  guard result.completed.length() == 1 else { fail("request must complete") }
  let completed = result.completed[0]
  guard completed.id == Number(1) else { fail("completed id must match") }
  guard completed.method_name == "remote/add" else {
    fail("method name must be preserved")
  }
  guard completed.result is Ok(Object(value)) else {
    fail("completion must contain result object")
  }
  guard value.get("value") is Some(Number(5.0, ..)) else {
    fail("completion value must be 5")
  }
}

///|
async test "outgoing request completes with remote error" {
  let endpoint = test_endpoint()
  ignore(endpoint.request("remote/unavailable"))
  let response =
    #|{"jsonrpc":"2.0","error":{"code":-32042,"message":"Temporarily unavailable","data":"retry later"},"id":1}
  let result = endpoint.receive_text(response)
  guard result.completed.length() == 1 else { fail("request must complete") }
  let completed = result.completed[0]
  guard completed.result
    is Err(
      RpcErrorWithData(
        code=-32042,
        message="Temporarily unavailable",
        data=String("retry later")
      )
    ) else {
    fail("completion must contain remote error")
  }
}

///|
async test "malformed remote error does not clear pending request" {
  let endpoint = test_endpoint()
  ignore(endpoint.request("remote/fractional"))

  let malformed =
    #|{"jsonrpc":"2.0","error":{"code":1.5,"message":"bad"},"id":1}
  let malformed_result = endpoint.receive_text(malformed)
  guard malformed_result.completed.is_empty() else {
    fail("malformed response must not complete")
  }
  guard malformed_result.unexpected.length() == 1 else {
    fail("malformed response must be unexpected")
  }

  let valid =
    #|{"jsonrpc":"2.0","result":"ok","id":1}
  let valid_result = endpoint.receive_text(valid)
  guard valid_result.completed.length() == 1 else {
    fail("pending request must still complete")
  }
  guard valid_result.completed[0].result is Ok(String("ok")) else {
    fail("valid response must complete with result")
  }
}

///|
test "auto id skips explicit pending numeric ids" {
  let endpoint = test_endpoint()
  let explicit = endpoint.request("remote/explicit", id=Number(1))
  guard explicit is Object(explicit_obj) else {
    fail("explicit request must be object")
  }
  guard explicit_obj.get("id") is Some(Number(1.0, ..)) else {
    fail("explicit id must be 1")
  }
  let automatic = endpoint.request("remote/auto")
  guard automatic is Object(auto_obj) else {
    fail("automatic request must be object")
  }
  guard auto_obj.get("id") is Some(Number(2.0, ..)) else {
    fail("automatic id must skip pending id")
  }
}

///|
test "explicit id and duplicate pending id" {
  let endpoint = test_endpoint()
  let first = endpoint.request("remote/one", id=String("abc"))
  guard first is Object(first_obj) else { fail("request must be object") }
  guard first_obj.get("id") is Some(String("abc")) else {
    fail("explicit id must be used")
  }
  let duplicate : Result[Json, EndpointError] = try? endpoint.request(
    "remote/two",
    id=String("abc"),
  )
  guard duplicate is Err(DuplicatePendingId(String("abc"))) else {
    fail("duplicate pending id must be rejected")
  }
}

///|
test "outgoing methods validate method names" {
  let endpoint = test_endpoint()
  let empty_request : Result[Json, EndpointError] = try? endpoint.request("")
  guard empty_request is Err(InvalidMethod("")) else {
    fail("empty request method must be rejected")
  }

  let reserved_request : Result[Json, EndpointError] = try? endpoint.request(
    "rpc.discover",
  )
  guard reserved_request is Err(ReservedMethod("rpc.discover")) else {
    fail("reserved request method must be rejected")
  }

  let empty_notification : Result[Json, EndpointError] = try? endpoint.notify(
    "",
  )
  guard empty_notification is Err(InvalidMethod("")) else {
    fail("empty notification method must be rejected")
  }

  let reserved_notification : Result[Json, EndpointError] = try? endpoint.notify(
    "rpc.discover",
  )
  guard reserved_notification is Err(ReservedMethod("rpc.discover")) else {
    fail("reserved notification method must be rejected")
  }
}

///|
async test "unexpected responses are observable" {
  let response =
    #|{"jsonrpc":"2.0","result":1,"id":99}
  let result = test_endpoint().receive_text(response)
  guard result.completed.is_empty() else {
    fail("unexpected must not complete")
  }
  guard result.unexpected.length() == 1 else {
    fail("unexpected response must be recorded")
  }
}

///|
async test "request with extra result member is still a request" {
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"result":0,"id":1}
  let response = response_json(test_endpoint(), request)
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("request must be dispatched")
  }
}

///|
async test "malformed response is unexpected and receives no response" {
  let response =
    #|{"jsonrpc":"2.0","result":1,"error":{"code":-32000,"message":"bad"},"id":99}
  let result = test_endpoint().receive_text(response)
  guard result.outgoing.is_empty() else {
    fail("response-like message must not receive a response")
  }
  guard result.unexpected.length() == 1 else {
    fail("malformed response must be observable")
  }
}

///|
async test "response id null is unexpected" {
  let response =
    #|{"jsonrpc":"2.0","result":1,"id":null}
  let result = test_endpoint().receive_text(response)
  guard result.unexpected.length() == 1 else {
    fail("null response id must be unexpected")
  }
}

///|
test "builder reports registration errors on build" {
  let reserved : Result[Endpoint, EndpointError] = try? @jsonrpc.EndpointBuilder()
    .handle("rpc.discover", ok_null)
    .build()
  guard reserved is Err(ReservedMethod("rpc.discover")) else {
    fail("reserved method must be rejected")
  }

  let duplicate : Result[Endpoint, EndpointError] = try? @jsonrpc.EndpointBuilder()
    .handle("echo", ok_null)
    .handle("echo", ok_null)
    .build()
  guard duplicate is Err(DuplicateMethod("echo")) else {
    fail("duplicate method must be rejected")
  }
}

///|
test "rpc error code must be an integer" {
  let fractional : Result[RpcError, @json.JsonDecodeError] = try? @json.from_json({
      "code": Json::number(1.5),
      "message": Json::string("fractional code"),
    },
  )
  guard fractional is Err(JsonDecodeError((path, _))) else {
    fail("fractional error code must be rejected")
  }
  guard path.to_json() is String("/code") else {
    fail("decode error path must identify code")
  }

  let valid : RpcError = @json.from_json({
    "code": Json::number((-32042).to_double()),
    "message": Json::string("valid code"),
  })
  guard valid is RpcError(code=-32042, message="valid code") else {
    fail("integer error code must decode")
  }
}

///|
test "batch helper creates json array" {
  let endpoint = test_endpoint()
  let one = endpoint.request("one")
  let two = endpoint.notify("two")
  let doc = batch([one, two])
  guard doc is Array(items) else { fail("batch helper must return array") }
  guard items.length() == 2 else { fail("batch must include two messages") }
}
