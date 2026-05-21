# Context

`shiguri-01/jsonrpc/context` binds application state to handlers. It does not define a separate server.

```mbt check
///|
struct DocPrefix {
  value : String
}

///|
#warnings("-73")
struct DocEchoParams {
  message : String
} derive(FromJson)

///|
struct DocEchoResult {
  message : String
} derive(ToJson)

///|
fn doc_echo(
  context : DocPrefix,
  params : DocEchoParams,
) -> Result[DocEchoResult, @rpc.RpcError] {
  Ok({ message: "\{context.value}\{params.message}" })
}

///|
test "context bind" {
  let prefix : DocPrefix = { value: "ctx:" }
  let handler = bind(prefix, doc_echo)
  let server = @rpc.Server::new().register("echo", handler).unwrap()
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
```

Use `bind_raw` or `register_raw` only when a context-aware method needs direct `Json?` access.
