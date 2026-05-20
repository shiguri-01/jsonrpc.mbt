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
- Handler API built around the public `Handler` alias:
  `Json? -> Result[Json, RpcError]`.
- Notification-only requests return `None` instead of an empty response.

## Public API

- `Server::new()`: create an empty dispatcher.
- `Server::register(name, handler)`: register a method. Names starting with
  `rpc.` are rejected because JSON-RPC reserves that prefix, and duplicate
  names are rejected to avoid accidental handler replacement.
- `Server::handle_text(input)`: parse and dispatch one JSON document, returning
  `Some(response)` or `None` for notifications.
- `Server::handle_json(value)`: dispatch an already parsed JSON value.
- `RpcError::new(code, message)` and `RpcError::with_data(...)`: return method
  errors from handlers.
- `invalid_params()` and `internal_error()`: helpers for common handler errors.

## Development

This repository uses Nix flakes and the community MoonBit overlay:

```sh
nix develop
moon test
moon run src/cmd/example
```

You can also run MoonBit directly through the overlay:

```sh
nix run github:moonbit-community/moonbit-overlay#moon -- test
```

## Example

```moonbit
fn echo(params : Json?) -> Result[Json, @rpc.RpcError] {
  Ok(params.unwrap_or(null))
}

let server = @rpc.Server::new()
  .register("echo", echo)
  .unwrap()

let response = server.handle_text(
  #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
)
```

See [src/cmd/example/main.mbt](src/cmd/example/main.mbt) for a runnable example.

## Spec Notes

JSON-RPC 2.0 is transport agnostic. A request object must include
`"jsonrpc": "2.0"` and a string `method`; `params`, when present, must be an
array or object; and a request without `id` is a notification. Notifications do
not receive responses, including when they appear inside a batch. Error
responses preserve a valid request `id` when one can be detected; parse errors
and invalid ids use `null`.

The official specification is published at <https://www.jsonrpc.org/specification>.
