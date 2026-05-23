///|
#warnings("-67-24")
async fn echo(params : Json?) -> Json raise @rpc.RpcError {
  params.unwrap_or(null)
}

///|
fn test_endpoint() -> @rpc.Endpoint raise @rpc.EndpointError {
  @rpc.EndpointBuilder().handle("echo", echo).build()
}

///|
async test "handle_line ignores empty lines" {
  guard handle_line(test_endpoint(), "\n") is None else {
    fail("empty line must produce no output")
  }
  guard handle_line(test_endpoint(), "   \n") is None else {
    fail("whitespace-only line must produce no output")
  }
}

///|
async test "handle_line writes one response line for one request line" {
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  let output = handle_line(test_endpoint(), "\{input}\n")
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
async test "handle_line writes batch responses as one array line" {
  let input =
    #|[
    #|  {"jsonrpc":"2.0","method":"echo","params":{"message":"one"},"id":1},
    #|  {"jsonrpc":"2.0","method":"missing","id":2}
    #|]
  let output = handle_line(test_endpoint(), "\{input}\n")
  guard output is Some(text) else { fail("batch must produce output") }
  guard text.has_suffix("\n") else { fail("output must end with newline") }
  let json = @json.parse(text.trim().to_owned()) catch {
    _ => fail("response line must be JSON")
  }
  guard json is Array([Object(first), Object(second)]) else {
    fail("batch output must be a two item array")
  }
  guard first.get("result") is Some(Object(result)) else {
    fail("first response must include result")
  }
  guard result.get("message") is Some(String("one")) else {
    fail("first response must preserve params")
  }
  guard second.get("error") is Some(Object(error)) else {
    fail("second response must include error")
  }
  guard error.get("code") is Some(Number(-32601.0, ..)) else {
    fail("second response must be method not found")
  }
}

///|
async test "handle_line writes one error line for malformed json" {
  let output = handle_line(test_endpoint(), "{\"jsonrpc\":\n")
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
async test "handle_line suppresses notification output" {
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"}}
  guard handle_line(test_endpoint(), "\{input}\n") is None else {
    fail("notification must produce no output")
  }
}
