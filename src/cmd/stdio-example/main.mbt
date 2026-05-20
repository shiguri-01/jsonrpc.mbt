///|
fn echo(params : Json?) -> Result[Json, @rpc.RpcError] {
  Ok(params.unwrap_or(null))
}

///|
async fn main {
  let server = @rpc.Server::new().register("echo", echo).unwrap()
  @rpc_stdio.run_lines(server)
}
