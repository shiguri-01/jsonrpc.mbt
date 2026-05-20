///|
fn add_pair(pair : (Double, Double)) -> Result[Json, @rpc.RpcError] {
  let (a, b) = pair
  Ok(Json::number(a + b))
}

///|
test "typed handler decodes positional params" {
  let server = @rpc.Server::new()
    .register("add", handler(array2(number, number), add_pair))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("result must be 5")
  }
}

///|
test "typed handler returns invalid params from decoder" {
  let server = @rpc.Server::new()
    .register("add", handler(array2(number, number), add_pair))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":["x",3],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32602.0, ..)) else {
    fail("error code must be invalid params")
  }
}
