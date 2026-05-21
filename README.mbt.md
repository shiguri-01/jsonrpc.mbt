# jsonrpc.mbt

A small JSON-RPC 2.0 server library for MoonBit.

The core package handles request validation, method dispatch, notifications, batches, and JSON-RPC error responses. Transports stay separate.

## Example

```moonbit
struct EchoParams {
  message : String
} derive(FromJson)

struct EchoResult {
  message : String
} derive(ToJson)

fn echo(params : EchoParams) -> Result[EchoResult, @rpc.RpcError] {
  Ok({ message: params.message })
}

let server = @rpc.Server::new()
  .register("echo", echo)
  .unwrap()

let response = server.handle_text(
  #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
)
```

`register` accepts params with `FromJson` and results with `ToJson`. Use `register_raw` for methods that need direct `Json?` access.

## Packages

- `shiguri/jsonrpc`: core dispatcher
- `shiguri/jsonrpc/context`: bind application state to handlers
- `shiguri/jsonrpc/stdio`: native-only stdin/stdout transport

## Development

```sh
nix develop
moon test
moon check --target native --warn-list +73
moon -C examples run basic
```

See [examples/README.mbt.md](examples/README.mbt.md) for runnable examples.

Spec: <https://www.jsonrpc.org/specification>
