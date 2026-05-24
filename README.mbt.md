# shiguri-01/jsonrpc

A small JSON-RPC 2.0 endpoint library for MoonBit.

The core package works with complete JSON-RPC messages.
Transport packages and application code decide how messages are framed and delivered.

## Install

```sh
moon add shiguri-01/jsonrpc
```

## Packages

- `shiguri-01/jsonrpc`: core endpoint
- `shiguri-01/jsonrpc/session`: optional transport-neutral session helper
- `shiguri-01/jsonrpc/stdio`: native-only stdin/stdout transport

See [src/README.mbt.md](src/README.mbt.md) for core package usage,
[src/session/README.mbt.md](src/session/README.mbt.md) for the session helper,
and [src/stdio/README.mbt.md](src/stdio/README.mbt.md) for the stdio transport.

Runnable examples are in [examples/README.mbt.md](examples/README.mbt.md).

Spec: <https://www.jsonrpc.org/specification>
