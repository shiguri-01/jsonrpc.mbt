///|
fn response_json(server : Server, input : String) -> Json raise {
  match server.handle_text(input) {
    Some(text) => @json.parse(text) catch { _ => fail("response is not JSON") }
    None => fail("expected a response")
  }
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
fn update_handler(_params : Json?) -> Result[Json, RpcError] {
  Ok(null)
}

///|
fn foobar_handler(_params : Json?) -> Result[Json, RpcError] {
  Ok(Json::string("ignored"))
}

///|
fn unavailable_handler(_params : Json?) -> Result[Json, RpcError] {
  Err(
    RpcError::with_data(
      -32042,
      "Temporarily unavailable",
      Json::string("retry later"),
    ),
  )
}

///|
fn spec_server() -> Server {
  Server::new()
  .register("subtract", subtract_handler)
  .unwrap()
  .register("update", update_handler)
  .unwrap()
  .register("foobar", foobar_handler)
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
test "single request returns result" {
  let server = Server::new().register("add", add_handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":1}
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("jsonrpc") is Some(String("2.0")) else {
    fail("jsonrpc must be 2.0")
  }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("result must be 5")
  }
  guard obj.get("id") is Some(Number(1.0, ..)) else { fail("id must be 1") }
}

///|
test "notification has no response" {
  let server = Server::new().register("add", add_handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3]}
  let response = server.handle_text(request)
  guard response is None else { fail("notification must not respond") }
}

///|
test "method not found is a standard error" {
  let server = Server::new()
  let request =
    #|{"jsonrpc":"2.0","method":"missing","id":"x"}
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32601.0, ..)) else {
    fail("error code must be method not found")
  }
  guard obj.get("id") is Some(String("x")) else { fail("id must be x") }
}

///|
test "handler can return invalid params" {
  let server = Server::new().register("add", add_handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":{"left":1},"id":1}
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32602.0, ..)) else {
    fail("error code must be invalid params")
  }
  guard obj.get("id") is Some(Number(1.0, ..)) else { fail("id must be 1") }
}

///|
test "empty batch is invalid request" {
  let server = Server::new()
  let response = response_json(server, "[]")
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32600.0, ..)) else {
    fail("error code must be invalid request")
  }
  guard obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
test "batch omits notification responses" {
  let server = Server::new().register("add", add_handler).unwrap()
  let request =
    #|[
    #|  {"jsonrpc":"2.0","method":"add","params":[1,2],"id":1},
    #|  {"jsonrpc":"2.0","method":"add","params":[3,4]},
    #|  {"jsonrpc":"2.0","method":"add","params":[5,6],"id":2}
    #|]
  let response = response_json(server, request)
  guard response is Array(items) else {
    fail("batch response must be an array")
  }
  assert_eq(items.length(), 2)
}

///|
test "parse error uses null id" {
  let server = Server::new()
  let request = "{\"jsonrpc\":"
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32700.0, ..)) else {
    fail("error code must be parse error")
  }
  guard obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
test "request id null is a call id and is preserved" {
  let server = Server::new().register("add", add_handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":null}
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("result must be 5")
  }
  guard obj.get("id") is Some(Null) else { fail("id must be null") }
}

///|
test "fractional number id is accepted and preserved" {
  let server = Server::new().register("add", add_handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":1.5}
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("result must be 5")
  }
  guard obj.get("id") is Some(Number(1.5, ..)) else {
    fail("fractional id must be preserved")
  }
}

///|
test "handler user-defined error code is preserved" {
  let server = Server::new()
    .register("unavailable", unavailable_handler)
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"unavailable","id":"call-1"}
  let response = response_json(server, request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32042.0, ..)) else {
    fail("user-defined error code must be preserved")
  }
  guard error.get("data") is Some(String("retry later")) else {
    fail("user-defined error data must be preserved")
  }
  guard obj.get("id") is Some(String("call-1")) else {
    fail("id must be preserved")
  }
}

///|
test "spec example positional params order one" {
  let request =
    #|{"jsonrpc":"2.0","method":"subtract","params":[42,23],"id":1}
  let response = response_json(spec_server(), request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("result") is Some(Number(19.0, ..)) else {
    fail("result must be 19")
  }
  guard obj.get("id") is Some(Number(1.0, ..)) else { fail("id must be 1") }
}

///|
test "spec example positional params order two" {
  let request =
    #|{"jsonrpc":"2.0","method":"subtract","params":[23,42],"id":2}
  let response = response_json(spec_server(), request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("result") is Some(Number(-19.0, ..)) else {
    fail("result must be -19")
  }
  guard obj.get("id") is Some(Number(2.0, ..)) else { fail("id must be 2") }
}

///|
test "spec example named params order one" {
  let request =
    #|{"jsonrpc":"2.0","method":"subtract","params":{"subtrahend":23,"minuend":42},"id":3}
  let response = response_json(spec_server(), request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("result") is Some(Number(19.0, ..)) else {
    fail("result must be 19")
  }
  guard obj.get("id") is Some(Number(3.0, ..)) else { fail("id must be 3") }
}

///|
test "spec example named params order two" {
  let request =
    #|{"jsonrpc":"2.0","method":"subtract","params":{"minuend":42,"subtrahend":23},"id":4}
  let response = response_json(spec_server(), request)
  guard response is Object(obj) else { fail("response must be an object") }
  guard obj.get("result") is Some(Number(19.0, ..)) else {
    fail("result must be 19")
  }
  guard obj.get("id") is Some(Number(4.0, ..)) else { fail("id must be 4") }
}

///|
test "spec notification examples return no response" {
  let server = spec_server()
  let one =
    #|{"jsonrpc":"2.0","method":"update","params":[1,2,3,4,5]}
  let two =
    #|{"jsonrpc":"2.0","method":"foobar"}
  guard server.handle_text(one) is None else {
    fail("update notification must not respond")
  }
  guard server.handle_text(two) is None else {
    fail("foobar notification must not respond")
  }
}

///|
test "invalid request shapes use invalid request error" {
  let server = spec_server()
  let invalid_method =
    #|{"jsonrpc":"2.0","method":1,"params":"bar","id":1}
  let invalid_params_member =
    #|{"jsonrpc":"2.0","method":"foobar","params":"bar","id":2}
  let invalid_id =
    #|{"jsonrpc":"2.0","method":"foobar","id":[]}
  let invalid_version =
    #|{"jsonrpc":"1.0","method":"foobar","id":3}
  let invalid_method_response = response_json(server, invalid_method)
  let invalid_params_response = response_json(server, invalid_params_member)
  let invalid_id_response = response_json(server, invalid_id)
  let invalid_version_response = response_json(server, invalid_version)
  assert_error_code(invalid_method_response, -32600.0)
  assert_error_code(invalid_params_response, -32600.0)
  assert_error_code(invalid_id_response, -32600.0)
  assert_error_code(invalid_version_response, -32600.0)
  guard invalid_method_response is Object(method_obj) else {
    fail("response must be object")
  }
  guard invalid_params_response is Object(params_obj) else {
    fail("response must be object")
  }
  guard invalid_id_response is Object(id_obj) else {
    fail("response must be object")
  }
  guard invalid_version_response is Object(version_obj) else {
    fail("response must be object")
  }
  guard method_obj.get("id") is Some(Number(1.0, ..)) else {
    fail("invalid method response must preserve id")
  }
  guard params_obj.get("id") is Some(Number(2.0, ..)) else {
    fail("invalid params member response must preserve id")
  }
  guard id_obj.get("id") is Some(Null) else {
    fail("invalid id response must use null id")
  }
  guard version_obj.get("id") is Some(Number(3.0, ..)) else {
    fail("invalid version response must preserve id")
  }
}

///|
test "batch with all invalid non-object entries returns one error per entry" {
  let response = response_json(spec_server(), "[1,2,3]")
  guard response is Array(items) else { fail("response must be an array") }
  guard items.length() == 3 else { fail("response count must be 3") }
  assert_error_code(items[0], -32600.0)
  assert_error_code(items[1], -32600.0)
  assert_error_code(items[2], -32600.0)
}

///|
test "batch of only notifications returns no response" {
  let request =
    #|[
    #|  {"jsonrpc":"2.0","method":"update","params":[1,2,3,4,5]},
    #|  {"jsonrpc":"2.0","method":"foobar"}
    #|]
  guard spec_server().handle_text(request) is None else {
    fail("notification-only batch must not respond")
  }
}

///|
test "batch with invalid entries returns ordered call and error responses" {
  let request =
    #|[
    #|  {"jsonrpc":"2.0","method":"subtract","params":[42,23],"id":1},
    #|  {"jsonrpc":"2.0","method":"missing","id":2},
    #|  {"jsonrpc":"2.0","method":"foobar"},
    #|  {"foo":"boo"},
    #|  {"jsonrpc":"2.0","method":"subtract","params":[23,42],"id":3}
    #|]
  let response = response_json(spec_server(), request)
  guard response is Array(items) else { fail("response must be an array") }
  guard items.length() == 4 else { fail("batch response count must be 4") }
  guard items[0] is Object(first) else { fail("first response must be object") }
  guard first.get("result") is Some(Number(19.0, ..)) else {
    fail("first result must be 19")
  }
  assert_error_code(items[1], -32601.0)
  assert_error_code(items[2], -32600.0)
  guard items[3] is Object(last) else { fail("last response must be object") }
  guard last.get("result") is Some(Number(-19.0, ..)) else {
    fail("last result must be -19")
  }
}

///|
test "reserved rpc prefix cannot be registered" {
  let result = Server::new().register("rpc.discover", foobar_handler)
  guard result is Err(error) else { fail("reserved method must be rejected") }
  guard error.code == invalid_request_code else {
    fail("reserved method must use invalid request code")
  }
}

///|
test "duplicate method registration is rejected" {
  let server = Server::new().register("echo", foobar_handler).unwrap()
  let result = server.register("echo", foobar_handler)
  guard result is Err(error) else { fail("duplicate method must be rejected") }
  guard error.code == invalid_request_code else {
    fail("duplicate method must use invalid request code")
  }
}

///|
test "register returns a new server and leaves the original unchanged" {
  let original = Server::new()
  let registered = original.register("echo", foobar_handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","id":1}
  let original_response = response_json(original, request)
  let registered_response = response_json(registered, request)
  assert_error_code(original_response, -32601.0)
  guard registered_response is Object(obj) else {
    fail("response must be an object")
  }
  guard obj.get("result") is Some(String("ignored")) else {
    fail("returned server must include registered handler")
  }
}
