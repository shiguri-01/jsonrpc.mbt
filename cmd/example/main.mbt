///|
fn subtract(params : Json?) -> Result[Json, @rpc.RpcError] {
  match params {
    Some(Array([Number(minuend, ..), Number(subtrahend, ..)])) =>
      Ok(Json::number(minuend - subtrahend))
    Some(Object(obj)) =>
      match (obj.get("minuend"), obj.get("subtrahend")) {
        (Some(Number(minuend, ..)), Some(Number(subtrahend, ..))) =>
          Ok(Json::number(minuend - subtrahend))
        _ => Err(@rpc.invalid_params())
      }
    _ => Err(@rpc.invalid_params())
  }
}

///|
fn echo(params : Json?) -> Result[Json, @rpc.RpcError] {
  Ok(params.unwrap_or(null))
}

///|
fn main {
  let server = @rpc.Server::new()
    .register("subtract", subtract)
    .unwrap()
    .register("echo", echo)
    .unwrap()

  let request =
    #|[
    #|  {"jsonrpc":"2.0","method":"subtract","params":[42,23],"id":1},
    #|  {"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":"echo-1"},
    #|  {"jsonrpc":"2.0","method":"subtract","params":[1,2]}
    #|]

  match server.handle_text(request) {
    Some(response) => println(response)
    None => println("notification-only batch")
  }
}
