# Examples

This directory is a separate MoonBit module with a local dependency on the repository root. Run commands from the repository root with `moon -C examples`.

## basic

Registers `subtract` and `echo`, sends an in-memory batch request, and prints
the response JSON.

```sh
moon -C examples run basic
```

## stdio-example

Serves JSON-RPC over stdin/stdout. Each non-empty input line is one JSON-RPC document.

```sh
moon -C examples run --target native stdio-example
```

Example input:

```json
{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
```
