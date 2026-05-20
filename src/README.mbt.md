# Core Dispatcher

`shiguri/jsonrpc` is the transport-agnostic JSON-RPC 2.0 dispatcher. It owns
request validation, method lookup, notification handling, batch response
selection, and standard error response construction.

It deliberately does not own HTTP, stdio, WebSocket, authentication, logging, or
application state. Those concerns should live in transport or adapter packages.

## Dispatch Text

```mbt check
///|
fn echo(params : Json?) -> Result[Json, RpcError] {
  Ok(params.unwrap_or(null))
}

///|
test "core dispatches a request" {
  let server = Server::new().register("echo", echo).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Object(result)) else {
    fail("response must include result object")
  }
  guard result.get("message") is Some(String("hello")) else {
    fail("result must preserve params")
  }
}
```

## Notifications

Requests without `id` are notifications. They are dispatched, but no response is
returned.

```mbt check
///|
test "core suppresses notification response" {
  let server = Server::new().register("echo", echo).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"}}
  let response = server.handle_text(request)
  guard response is None else { fail("notification must not respond") }
}
```

## Batch

Batch handling keeps call responses and error responses in order, while omitting
notification responses.
