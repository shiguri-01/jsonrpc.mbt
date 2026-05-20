# Stdio Transport

`shiguri/jsonrpc/stdio` is a native-only transport adapter. It reads one
newline-delimited JSON-RPC document per input line and writes one response per
output line. Notifications produce no output.

The package depends on `moonbitlang/async/stdio`, so it is kept outside the core
dispatcher package.

```mbt nocheck
///|
async fn main {
  let server = @rpc.Server::new().register("echo", echo).unwrap()
  @rpc_stdio.run_lines(server)
}
```

Run the example package with the native backend:

```sh
moon run --target native src/cmd/stdio-example
```
