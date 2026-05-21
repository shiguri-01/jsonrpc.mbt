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
- Typed method registration built on MoonBit's `FromJson` and `ToJson` traits.
- Low-level raw JSON handler API available through `register_raw`.
- Notification-only requests return `None` instead of an empty response.

## Public API

- `Server::new()`: create an empty dispatcher.
- `Server::register(name, handler)`: register a JSON trait method. Request
  params are decoded with `FromJson`, and successful results are encoded with
  `ToJson`.
- `Server::register_raw(name, handler)`: register a low-level
  `Json? -> Result[Json, RpcError]` handler for cases that need direct JSON
  control.
- Both registration methods reject names starting with `rpc.` and duplicate
  names. Registration is builder-style: use the returned `Server`; the original
  value is unchanged.
- `Server::handle_text(input)`: parse and dispatch one JSON document, returning
  `Some(response)` or `None` for notifications.
- `Server::handle_json(value)`: dispatch an already parsed JSON value.
- `RpcError::new(code, message)` and `RpcError::with_data(...)`: return method
  errors from handlers.
- `invalid_params()` and `internal_error()`: helpers for common handler errors.

## Optional Packages

The core package stays small. Extra packages compose through `RawHandler` and
`Server` without adding transport or context concepts to the core.

- `shiguri/jsonrpc/context`: adapters for binding application state or request
  metadata to a normal core `RawHandler`.
- `shiguri/jsonrpc/stdio`: native-only newline-delimited stdin/stdout transport
  for quick CLIs and editor-style subprocesses.

## Import Paths and Aliases

Use quoted package paths in `moon.pkg`, then call them through `@alias` in
MoonBit code. Do not write `@shiguri/jsonrpc`; `@` applies to the local alias,
not to the package path.

```moonbit
import {
  "shiguri/jsonrpc" @rpc,
  "shiguri/jsonrpc/context" @context,
}
```

After that, code uses aliases such as `@rpc.Server::new()` and
`@context.bind(...)`.

## Development

This repository uses Nix flakes and the community MoonBit overlay:

```sh
nix develop
moon test
moon check --target native --warn-list +73
moon run src/cmd/example
```

You can also run MoonBit directly through the overlay:

```sh
nix run github:moonbit-community/moonbit-overlay#moon -- test
```

## Example

```moonbit
struct EchoParams {
  message : String
} derive(FromJson, ToJson)

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

See [src/cmd/example/main.mbt](src/cmd/example/main.mbt) for a runnable example.

## Typed Methods

Use normal MoonBit types for application params and results. For named params,
derive JSON traits on structs:

```moonbit
struct AddParams {
  left : Int
  right : Int
} derive(FromJson, ToJson)

struct AddResult {
  value : Int
} derive(ToJson)

fn add(params : AddParams) -> Result[AddResult, @rpc.RpcError] {
  Ok({ value: params.left + params.right })
}

let server = @rpc.Server::new().register("add", add).unwrap()
```

For positional params, use MoonBit tuples. `FromJson` and `ToJson` support
tuples directly:

```moonbit
fn subtract(params : (Int, Int)) -> Result[Int, @rpc.RpcError] {
  let (left, right) = params
  Ok(left - right)
}
```

When a method genuinely needs to inspect raw JSON, register it explicitly as a
low-level handler:

```moonbit
fn raw_echo(params : Json?) -> Result[Json, @rpc.RpcError] {
  Ok(params.unwrap_or(null))
}

let server = @rpc.Server::new().register_raw("echo", raw_echo).unwrap()
```

## Context

Use `context` when a method needs application state. The core `Server` still
receives a plain `RawHandler`.

```moonbit
let handler = @context.bind(app_state, method_using_state)
```

## Stdio

`stdio` treats each non-empty input line as one complete JSON-RPC document and
writes each response as one output line. Notifications produce no output.
`@rpc_stdio.handle_line(...)` contains the pure one-line behavior used by the
async loop, which keeps newline-delimited dispatch testable.

```sh
moon run --target native src/cmd/stdio-example
```

## Spec Notes

JSON-RPC 2.0 is transport agnostic. A request object must include
`"jsonrpc": "2.0"` and a string `method`; `params`, when present, must be an
array or object; and a request without `id` is a notification. Notifications do
not receive responses, including when they appear inside a batch. Error
responses preserve a valid request `id` when one can be detected; parse errors
and invalid ids use `null`. This implementation preserves `id: null` and
numeric ids, including fractional numbers, even though the JSON-RPC
specification discourages fractional ids for interoperability.

The official specification is published at <https://www.jsonrpc.org/specification>.
