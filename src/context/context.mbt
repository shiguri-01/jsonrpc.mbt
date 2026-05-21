///|
/// JSON trait method handler that receives application context.
pub type Handler[C, P, R] = (C, P) -> Result[R, @rpc.RpcError]

///|
/// Low-level JSON-RPC handler that receives application context.
pub type RawHandler[C] = (C, Json?) -> Result[Json, @rpc.RpcError]

///|
/// Bind application context to a context-aware handler.
pub fn[C, P, R] bind(
  context : C,
  handler : Handler[C, P, R],
) -> (P) -> Result[R, @rpc.RpcError] {
  params => handler(context, params)
}

///|
/// Register a context-aware JSON trait handler on a core server.
pub fn[C, P : @json.FromJson, R : ToJson] register(
  server : @rpc.Server,
  name : String,
  context : C,
  handler : Handler[C, P, R],
) -> Result[@rpc.Server, @rpc.RpcError] {
  server.register(name, bind(context, handler))
}

///|
/// Bind application context to a low-level JSON handler.
///
/// This keeps core `Server` transport-agnostic while still letting applications
/// pass state, configuration, or request metadata through an adapter layer.
pub fn[C] bind_raw(context : C, handler : RawHandler[C]) -> @rpc.RawHandler {
  params => handler(context, params)
}

///|
/// Register a context-aware low-level JSON handler on a core server.
pub fn[C] register_raw(
  server : @rpc.Server,
  name : String,
  context : C,
  handler : RawHandler[C],
) -> Result[@rpc.Server, @rpc.RpcError] {
  server.register_raw(name, bind_raw(context, handler))
}
