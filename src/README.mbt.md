# shiguri-01/jsonrpc

A small JSON-RPC 2.0 server library for MoonBit.

The core package validates JSON-RPC 2.0 requests, dispatches methods, and builds responses.
Transport code stays separate, so the same server can be used from HTTP, WebSocket, CLI, stdio, tests, or another runtime boundary.

## Usage

```mbt
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
let server = @rpc.Server::new()
  .register("echo", echo)
  .unwrap()

let response = server.handle_text(
  #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
)
```

`register` works with MoonBit's `FromJson` and `ToJson` traits.
Use `register_raw` only when a method needs direct `Json?` access.

`Server::register` is builder-style: use the returned `Server`.
`Server::handle_text` accepts one JSON document and returns `None` for notifications or notification-only batches.

## Packages

- `shiguri-01/jsonrpc`: core dispatcher
- `shiguri-01/jsonrpc/context`: bind application state to handlers
- `shiguri-01/jsonrpc/stdio`: native-only stdin/stdout transport

See [examples/README.mbt.md](examples/README.mbt.md) for runnable examples.

Spec: <https://www.jsonrpc.org/specification>
