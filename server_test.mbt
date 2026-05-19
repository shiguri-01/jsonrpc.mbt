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
