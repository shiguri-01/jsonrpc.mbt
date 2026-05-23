# Examples

This directory is a separate MoonBit module with a local dependency on the repository root. Run commands from the repository root with `moon -C examples`.

## basic

Registers `subtract` and `echo`, sends an in-memory batch document with two
requests and one notification, and prints the response JSON.

```sh
moon -C examples run basic
```

## stdio

Serves JSON-RPC over stdin/stdout. Each non-empty input line is one JSON-RPC document.
The example prints usage hints to stderr so stdout stays reserved for JSON-RPC
responses.

```sh
moon -C examples run stdio
```

Example input:

```json
{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
```
