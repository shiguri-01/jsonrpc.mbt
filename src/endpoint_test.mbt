///|
fn response_json(endpoint : Endpoint, input : String) -> Json raise {
  let result = endpoint.receive_text(input)
  guard result.outgoing.length() == 1 else {
    fail("expected one outgoing response")
  }
  result.outgoing[0]
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
fn add(params : AddParams) -> Result[AddResult, RpcError] {
  Ok({ value: params.left + params.right })
}

///|
fn add_tuple(params : (Int, Int)) -> Result[Int, RpcError] {
  let (left, right) = params
  Ok(left + right)
}

///|
fn ping(_params : Unit) -> Result[String, RpcError] {
  Ok("pong")
}

///|
fn add_handler(params : Json?) -> Result[Json, RpcError] {
  match params {
    Some(Array([Number(a, ..), Number(b, ..)])) => Ok(Json::number(a + b))
    _ => Err(invalid_params())
  }
}

///|
fn subtract_handler(params : Json?) -> Result[Json, RpcError] {
  match params {
    Some(Array([Number(minuend, ..), Number(subtrahend, ..)])) =>
      Ok(Json::number(minuend - subtrahend))
    Some(Object(obj)) =>
      match (obj.get("minuend"), obj.get("subtrahend")) {
        (Some(Number(minuend, ..)), Some(Number(subtrahend, ..))) =>
          Ok(Json::number(minuend - subtrahend))
        _ => Err(invalid_params())
      }
    _ => Err(invalid_params())
  }
}

///|
fn ok_null(_params : Json?) -> Result[Json, RpcError] {
  Ok(null)
}

///|
fn unavailable(_params : Json?) -> Result[Json, RpcError] {
  Err(
    RpcError(
      -32042,
      "Temporarily unavailable",
      data=Json::string("retry later"),
    ),
  )
}

///|
fn test_endpoint() -> Endpoint {
  @jsonrpc.EndpointBuilder()
  .handle("add", add_handler)
  .handle("subtract", subtract_handler)
  .handle("update", ok_null)
  .handle("unavailable", unavailable)
  .build()
  .unwrap()
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
test "builder registers raw and typed handlers" {
  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("add", typed(add))
    .handle("tuple/add", typed(add_tuple))
    .handle("ping", typed(ping))
    .build()
    .unwrap()
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
test "typed decode failures become invalid params" {
  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("add", typed(add))
    .build()
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":{"left":"two","right":3},"id":1}
  let response = response_json(endpoint, request)
  assert_error_code(response, -32602.0)
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
test "notification produces no outgoing response" {
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
test "request id null is preserved for incoming calls" {
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
test "method not found and parse errors are protocol errors" {
  let endpoint = test_endpoint()
  let missing_request =
    #|{"jsonrpc":"2.0","method":"missing","id":"x"}
  let missing = response_json(endpoint, missing_request)
  assert_error_code(missing, -32601.0)
  guard missing is Object(missing_obj) else { fail("response must be object") }
  guard missing_obj.get("id") is Some(String("x")) else {
    fail("id must be preserved")
  }

  let parse_error = response_json(endpoint, "{\"jsonrpc\":")
  assert_error_code(parse_error, -32700.0)
  guard parse_error is Object(parse_obj) else {
    fail("response must be object")
  }
  guard parse_obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
test "batch receive accumulates outgoing messages in order" {
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
  assert_error_code(result.outgoing[1], -32600.0)
  guard result.outgoing[2] is Object(last) else { fail("last must be object") }
  guard last.get("result") is Some(Number(-19.0, ..)) else {
    fail("last result must be -19")
  }
}

///|
test "empty batch returns invalid request response" {
  let response = response_json(test_endpoint(), "[]")
  assert_error_code(response, -32600.0)
  guard response is Object(obj) else { fail("response must be object") }
  guard obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
test "outgoing request auto id and completion" {
  let endpoint = test_endpoint()
  let request = endpoint
    .request("remote/add", params=Json::array([Json::number(2.0)]))
    .unwrap()
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
test "explicit id and duplicate pending id" {
  let endpoint = test_endpoint()
  let first = endpoint.request("remote/one", id=String("abc")).unwrap()
  guard first is Object(first_obj) else { fail("request must be object") }
  guard first_obj.get("id") is Some(String("abc")) else {
    fail("explicit id must be used")
  }
  let duplicate = endpoint.request("remote/two", id=String("abc"))
  guard duplicate is Err(DuplicatePendingId(String("abc"))) else {
    fail("duplicate pending id must be rejected")
  }
}

///|
test "unexpected responses are observable" {
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
test "response id null is unexpected" {
  let response =
    #|{"jsonrpc":"2.0","result":1,"id":null}
  let result = test_endpoint().receive_text(response)
  guard result.unexpected.length() == 1 else {
    fail("null response id must be unexpected")
  }
}

///|
test "builder reports registration errors on build" {
  let reserved = @jsonrpc.EndpointBuilder()
    .handle("rpc.discover", ok_null)
    .build()
  guard reserved is Err(ReservedMethod("rpc.discover")) else {
    fail("reserved method must be rejected")
  }

  let duplicate = @jsonrpc.EndpointBuilder()
    .handle("echo", ok_null)
    .handle("echo", ok_null)
    .build()
  guard duplicate is Err(DuplicateMethod("echo")) else {
    fail("duplicate method must be rejected")
  }
}

///|
test "batch helper creates json array" {
  let endpoint = test_endpoint()
  let one = endpoint.request("one").unwrap()
  let two = endpoint.notify("two").unwrap()
  let doc = batch([one, two])
  guard doc is Array(items) else { fail("batch helper must return array") }
  guard items.length() == 2 else { fail("batch must include two messages") }
}
