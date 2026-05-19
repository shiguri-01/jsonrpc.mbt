# jsonrpc.mbt

A small, transport-agnostic JSON-RPC 2.0 server library for MoonBit.

The library focuses on one responsibility: accepting a JSON value or JSON text,
dispatching it to registered methods, and returning the JSON-RPC response value
when the specification requires one. HTTP, stdio, sockets, auth, logging, and
application state stay outside the core dispatcher.

## Features

- JSON-RPC 2.0 request validation based on the official specification.
- Single request, notification, and batch handling.
- Standard error codes: parse error, invalid request, method not found, invalid
  params, and internal error.
- Handler API built around `Json? -> Result[Json, RpcError]`.
- Notification-only requests return `None` instead of an empty response.

## Development

This repository uses Nix flakes and the community MoonBit overlay:

```sh
nix develop
moon test
moon run cmd/example
```

You can also run MoonBit directly through the overlay:

```sh
nix run github:moonbit-community/moonbit-overlay#moon -- test
```

## Example

```moonbit
fn echo(params : Json?) -> Result[Json, @rpc.RpcError] {
  Ok(params.unwrap_or(Null))
}

let server = @rpc.Server::new()
  .register("echo", echo)
  .unwrap()

let response = server.handle_text(
  #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
)
```

See [cmd/example/main.mbt](cmd/example/main.mbt) for a runnable example.

## Spec Notes

JSON-RPC 2.0 is transport agnostic. A request object must include
`"jsonrpc": "2.0"` and a string `method`; `params`, when present, must be an
array or object; and a request without `id` is a notification. Notifications do
not receive responses, including when they appear inside a batch.

The official specification is published at <https://www.jsonrpc.org/specification>.
