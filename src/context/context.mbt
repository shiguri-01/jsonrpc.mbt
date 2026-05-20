///|
/// JSON-RPC handler that receives application context.
pub type Handler[C] = (C, Json?) -> Result[Json, @rpc.RpcError]

///|
/// Bind application context to a context-aware handler.
///
/// This keeps core `Server` transport-agnostic while still letting applications
/// pass state, configuration, or request metadata through an adapter layer.
pub fn[C] bind(context : C, handler : Handler[C]) -> @rpc.Handler {
  params => handler(context, params)
}

///|
/// Register a context-aware handler on a core server.
pub fn[C] register(
  server : @rpc.Server,
  name : String,
  context : C,
  handler : Handler[C],
) -> Result[@rpc.Server, @rpc.RpcError] {
  server.register(name, bind(context, handler))
}
