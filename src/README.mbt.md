# Core Dispatcher

`shiguri/jsonrpc` validates JSON-RPC 2.0 requests, dispatches methods, and builds responses.

## Dispatch Text

```mbt check
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
fn echo(params : EchoParams) -> Result[EchoResult, RpcError] {
  Ok({ message: params.message })
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

`Server::register` is builder-style: use the returned `Server`.
Use `Server::register_raw` only when a method needs direct `Json?` access.

## Notifications

Requests without `id` are notifications. They are dispatched, but no response is returned.

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

Batch responses preserve call/error order and omit notifications.
