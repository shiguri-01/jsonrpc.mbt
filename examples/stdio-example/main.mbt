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
  let server = @rpc.Server::new().register("echo", echo).unwrap()
  @rpc_stdio.run_lines(server)
}
