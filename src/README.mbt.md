# shiguri-01/jsonrpc

A small JSON-RPC 2.0 endpoint library for MoonBit.

The core package validates JSON-RPC 2.0 messages, dispatches methods, builds
responses, creates outgoing requests, and tracks pending responses. Transport
code stays separate, so the same endpoint can be used from HTTP, WebSocket, CLI,
stdio, tests, or another runtime boundary.

## Usage

```mbt nocheck
///|
struct EchoParams {
  message : String
} derive(FromJson)

///|
struct EchoResult {
  message : String
} derive(ToJson)

///|
fn echo(params : EchoParams) -> Result[EchoResult, @rpc.RpcError] {
  Ok({ message: params.message })
}

///|
let endpoint = @rpc.EndpointBuilder()
  .handle("echo", @rpc.typed(echo))
  .build()
  .unwrap()

///|
let received = endpoint.receive_text(
  (
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  ),
)
```

`EndpointBuilder::handle` registers one handler shape:
`(Json?) -> Result[Json, RpcError]`. Use `typed` when a method should decode
params with MoonBit's `FromJson` trait and encode results with `ToJson`.

`Endpoint::receive_text` accepts one JSON document and returns a
`ReceiveResult`. Send `ReceiveResult.outgoing` through your transport. Locally
created requests are completed through `ReceiveResult.completed`.

## Packages

- `shiguri-01/jsonrpc`: core endpoint
- `shiguri-01/jsonrpc/stdio`: native-only stdin/stdout transport

See [examples/README.mbt.md](examples/README.mbt.md) for runnable examples.

Spec: <https://www.jsonrpc.org/specification>
