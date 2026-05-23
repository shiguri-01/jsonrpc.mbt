# Stdio Transport

`shiguri-01/jsonrpc/stdio` is a native-only stdin/stdout transport. It reads one JSON-RPC document per line and writes one response per line. Notifications produce no output.

`handle_line(endpoint, line)` is the one-line helper used by `run_lines`.

```mbt check
///|
#warnings("-73")
struct StdioEchoParams {
  message : String
} derive(FromJson)

///|
struct StdioEchoResult {
  message : String
} derive(ToJson)

///|
#warnings("-67-24")
async fn stdio_echo(
  params : StdioEchoParams,
) -> StdioEchoResult raise @rpc.RpcError {
  { message: params.message }
}

///|
async test "handle_line" {
  let endpoint = @rpc.EndpointBuilder()
    .handle("echo", @rpc.typed(stdio_echo))
    .build()
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  guard handle_line(endpoint, input) is Some(_) else {
    fail("expected response line")
  }
}
```

Run the example with the native backend:

```sh
moon -C examples run stdio
```
