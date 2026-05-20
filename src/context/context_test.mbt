///|
struct Prefix {
  value : String
}

///|
fn prefixed_echo(
  context : Prefix,
  params : Json?,
) -> Result[Json, @rpc.RpcError] {
  match params {
    Some(Array([String(message)])) =>
      Ok(Json::string("\{context.value}\{message}"))
    _ => Err(@rpc.invalid_params())
  }
}

///|
test "bind adapts context handler to core handler" {
  let server = @rpc.Server::new()
    .register("echo", bind({ value: "hi " }, prefixed_echo))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":["there"],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(String("hi there")) else {
    fail("result must include context")
  }
}

///|
test "register adds context handler to server" {
  let server = register(
    @rpc.Server::new(),
    "echo",
    { value: "ctx:" },
    prefixed_echo,
  ).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":["ok"],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(String("ctx:ok")) else {
    fail("result must include context")
  }
}
