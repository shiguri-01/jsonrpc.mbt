# Session Helper

`shiguri-01/jsonrpc/session` is an optional helper layer between the core
endpoint and transports. It does not read or write bytes. Instead, it accepts
complete JSON-RPC documents and returns the response document that a transport
can frame and write.

```mbt check
///|
#warnings("-unused_async-unused_error_type")
async fn session_echo(params : Json?) -> Json raise @rpc.RpcError {
  params.unwrap_or(null)
}

///|
pub async fn session_usage() -> Unit {
  let endpoint = @rpc.EndpointBuilder().handle("echo", session_echo).build()
  let session = @session.Session(endpoint)

  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  let turn = session.receive_text(input)

  // The transport chooses its own framing around this JSON text.
  ignore(turn.response_text())
}
```

Use the core `Endpoint` directly when you want lower-level control.
