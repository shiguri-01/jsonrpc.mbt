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
fn echo(params : EchoParams) -> Result[EchoResult, @rpc.RpcError] {
  Ok({ message: params.message })
}

///|
async fn main {
  let endpoint = @rpc.EndpointBuilder::EndpointBuilder()
    .handle("echo", @rpc.typed(echo))
    .build()
    .unwrap()
  @rpc_stdio.run_lines(endpoint)
}
