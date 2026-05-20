# Context

`shiguri/jsonrpc/context` adapts stateful handlers to the core `Handler` type.
It is useful for application state, configuration, or metadata captured by a
transport layer.

The package does not define a new server. It only binds context to a handler or
registers that bound handler on a core `Server`.

```mbt check
///|
struct DocPrefix {
  value : String
}

///|
fn doc_echo(context : DocPrefix, params : Json?) -> Result[Json, @rpc.RpcError] {
  match params {
    Some(Array([String(message)])) =>
      Ok(Json::string("\{context.value}\{message}"))
    _ => Err(@rpc.invalid_params())
  }
}

///|
test "context bind" {
  let prefix : DocPrefix = { value: "ctx:" }
  let handler = bind(prefix, doc_echo)
  let server = @rpc.Server::new().register("echo", handler).unwrap()
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
```
