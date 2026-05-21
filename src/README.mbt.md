# shiguri-01/jsonrpc

A small JSON-RPC 2.0 endpoint library for MoonBit.

The core package validates JSON-RPC 2.0 messages, dispatches methods, builds
responses, creates outgoing requests, and tracks pending responses. Transport
code stays separate, so the same endpoint can be used from HTTP, WebSocket, CLI,
stdio, tests, or another runtime boundary.

## Usage

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
fn echo(params : EchoParams) -> Result[EchoResult, @jsonrpc.RpcError] {
  Ok({ message: params.message })
}

///|
test "receive call" {
  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("echo", @jsonrpc.typed(echo))
    .build()
    .unwrap()
  let received = endpoint.receive_text(
    (
      #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
    ),
  )
  guard received.outgoing.length() == 1 else { fail("expected response") }
}
```

`EndpointBuilder::handle` registers one handler shape:
`(Json?) -> Result[Json, RpcError]`. Use `typed` when a method should decode
params with MoonBit's `FromJson` trait and encode results with `ToJson`.

`Endpoint::receive_text` accepts one JSON document and returns a
`ReceiveResult`. Send `ReceiveResult.outgoing` through your transport.

The same endpoint can also create local requests and match later responses.

```mbt check
///|
test "send call" {
  let endpoint = @jsonrpc.EndpointBuilder().build().unwrap()
  let request = endpoint.request("workspace/configuration").unwrap()
  guard request.stringify() != "" else { fail("request must be JSON") }
  let response = endpoint.receive_text(
    (
      #|{"jsonrpc":"2.0","result":{"format":"json"},"id":1}
    ),
  )
  guard response.completed.length() == 1 else { fail("expected completion") }
}
```

Send `request` through your transport. When the peer sends a response with the
same id, it appears in `ReceiveResult.completed`.

Notifications are created without pending response state.

```mbt check
///|
test "send notification" {
  let endpoint = @jsonrpc.EndpointBuilder().build().unwrap()
  let notification = endpoint.notify("window/logMessage", params=null).unwrap()
  guard notification.stringify() != "" else {
    fail("notification must be JSON")
  }
}
```

Configuration and application-owned data stay outside the core endpoint. Capture
the value a handler needs in a closure, or wrap that pattern in your own small
adapter.

```mbt check
///|
struct AppConfig {
  prefix : String
}

///|
#warnings("-73")
struct GreetParams {
  name : String
} derive(FromJson)

///|
struct GreetResult {
  message : String
} derive(ToJson)

///|
fn greet(
  config : AppConfig,
  params : GreetParams,
) -> Result[GreetResult, @jsonrpc.RpcError] {
  Ok({ message: "\{config.prefix}, \{params.name}" })
}

///|
test "application data" {
  let config : AppConfig = { prefix: "hello" }
  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("greet", @jsonrpc.typed(params => greet(config, params)))
    .build()
    .unwrap()
  let received = endpoint.receive_text(
    (
      #|{"jsonrpc":"2.0","method":"greet","params":{"name":"MoonBit"},"id":1}
    ),
  )
  guard received.outgoing.length() == 1 else { fail("expected response") }
}
```

## Packages

- `shiguri-01/jsonrpc`: core endpoint
- `shiguri-01/jsonrpc/stdio`: native-only stdin/stdout transport

See [examples/README.mbt.md](examples/README.mbt.md) for runnable examples.

Spec: <https://www.jsonrpc.org/specification>
