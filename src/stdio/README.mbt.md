# Stdio Transport

`shiguri-01/jsonrpc/stdio` is a native-only stdin/stdout transport. It reads one JSON-RPC document per line and writes one response per line. Notifications produce no output.

`handle_line(endpoint, line)` is the one-line helper used by `run_lines`.

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
async fn main {
  let endpoint = @rpc.EndpointBuilder()
    .handle("echo", @rpc.typed(echo))
    .build()
    .unwrap()
  @rpc_stdio.run_lines(endpoint)
}
```

Run the example with the native backend:

```sh
moon -C examples run --target native stdio-example
```
