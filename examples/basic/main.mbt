///|
#warnings("-73")
struct SubtractParams {
  minuend : Int
  subtrahend : Int
} derive(FromJson)

///|
struct SubtractResult {
  value : Int
} derive(ToJson)

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
async fn subtract(
  params : SubtractParams,
) -> SubtractResult raise @rpc.RpcError {
  { value: params.minuend - params.subtrahend }
}

///|
#warnings("-67-24")
async fn echo(params : EchoParams) -> EchoResult raise @rpc.RpcError {
  { message: params.message }
}

///|
async fn main {
  let endpoint = @rpc.EndpointBuilder()
    .handle("subtract", @rpc.typed(subtract))
    .handle("echo", @rpc.typed(echo))
    .build()
    catch { _ => abort("failed to build endpoint") }

  let request =
    #|[
    #|  {"jsonrpc":"2.0","method":"subtract","params":{"minuend":42,"subtrahend":23},"id":1},
    #|  {"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":"echo-1"},
    #|  {"jsonrpc":"2.0","method":"subtract","params":{"minuend":1,"subtrahend":2}}
    #|]

  let result = endpoint.receive_text(request) catch {
    _ => abort("failed to receive request")
  }
  match result.outgoing.length() {
    0 => println("notification-only batch")
    1 => println(result.outgoing[0].stringify())
    _ => println(Json::array(result.outgoing).stringify())
  }
}
