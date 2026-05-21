///|
fn echo(params : Json?) -> Result[Json, @rpc.RpcError] {
  Ok(params.unwrap_or(null))
}

///|
fn test_server() -> @rpc.Server {
  @rpc.Server::new().register_raw("echo", echo).unwrap()
}

///|
test "handle_line ignores empty lines" {
  guard handle_line(test_server(), "\n") is None else {
    fail("empty line must produce no output")
  }
  guard handle_line(test_server(), "   \n") is None else {
    fail("whitespace-only line must produce no output")
  }
}

///|
test "handle_line writes one response line for one request line" {
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  let output = handle_line(test_server(), "\{input}\n")
  guard output is Some(text) else { fail("request must produce output") }
  guard text.has_suffix("\n") else { fail("output must end with newline") }
  let json = @json.parse(text.trim().to_owned()) catch {
    _ => fail("response line must be JSON")
  }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Object(result)) else {
    fail("response must include result object")
  }
  guard result.get("message") is Some(String("hello")) else {
    fail("result must preserve params")
  }
}

///|
test "handle_line writes one error line for malformed json" {
  let output = handle_line(test_server(), "{\"jsonrpc\":\n")
  guard output is Some(text) else { fail("parse error must produce output") }
  guard text.has_suffix("\n") else { fail("output must end with newline") }
  let json = @json.parse(text.trim().to_owned()) catch {
    _ => fail("response line must be JSON")
  }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32700.0, ..)) else {
    fail("error code must be parse error")
  }
}

///|
test "handle_line suppresses notification output" {
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"}}
  guard handle_line(test_server(), "\{input}\n") is None else {
    fail("notification must produce no output")
  }
}
