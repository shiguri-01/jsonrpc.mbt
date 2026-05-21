///|
struct Prefix {
  value : String
}

///|
#warnings("-73")
struct EchoParams {
  message : String
} derive(FromJson)

///|
struct EchoResult {
  message : String
} derive(ToJson)

///|
fn prefixed_json_trait_echo(
  context : Prefix,
  params : EchoParams,
) -> Result[EchoResult, @rpc.RpcError] {
  Ok({ message: "\{context.value}\{params.message}" })
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
  let prefix : Prefix = { value: "hi " }
  let server = @rpc.Server::new()
    .register("echo", bind(prefix, prefixed_json_trait_echo))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"there"},"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Object(result)) else {
    fail("response must include result object")
  }
  guard result.get("message") is Some(String("hi there")) else {
    fail("result must include context")
  }
}

///|
test "register adds context handler to server" {
  let prefix : Prefix = { value: "ctx:" }
  let server = register(
    @rpc.Server::new(),
    "echo",
    prefix,
    prefixed_json_trait_echo,
  ).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"ok"},"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Object(result)) else {
    fail("response must include result object")
  }
  guard result.get("message") is Some(String("ctx:ok")) else {
    fail("result must include context")
  }
}

///|
test "bind_raw adapts low-level context handler to raw core handler" {
  let prefix : Prefix = { value: "raw:" }
  let server = @rpc.Server::new()
    .register_raw("echo", bind_raw(prefix, prefixed_echo))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":["ok"],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(String("raw:ok")) else {
    fail("result must include context")
  }
}

///|
test "register_raw adds low-level context handler to server" {
  let prefix : Prefix = { value: "raw-register:" }
  let server = register_raw(@rpc.Server::new(), "echo", prefix, prefixed_echo).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":["ok"],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(String("raw-register:ok")) else {
    fail("result must include context")
  }
}
