///|
#warnings("-73")
struct EchoParams {
  message : String
} derive(FromJson)

///|
struct EchoResult {
  message : String
} derive(ToJson)

///|
#warnings("-67-24")
async fn echo(params : EchoParams) -> EchoResult raise @rpc.RpcError {
  { message: params.message }
}

///|
async fn main {
  let endpoint = @rpc.EndpointBuilder()
    .handle("echo", @rpc.typed(echo))
    .build()
    .unwrap()

  @async_stdio.stderr.write("JSON-RPC stdio example is ready.\n")
  @async_stdio.stderr.write("Send one JSON-RPC document per line on stdin.\n")
  @async_stdio.stderr.write(
    (
      #|Example: {"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
    ),
  )
  @async_stdio.stderr.write("\n")
  @rpc_stdio.run_lines(endpoint)
}
