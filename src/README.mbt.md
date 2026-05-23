# shiguri-01/jsonrpc

A small JSON-RPC 2.0 endpoint library for MoonBit.

The core package works with complete JSON-RPC messages. Transports such as
stdio, WebSocket, and HTTP stay outside the core.

## Usage

```mbt check
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
async fn echo(params : EchoParams) -> EchoResult raise @jsonrpc.RpcError {
  { message: params.message }
}

///|
pub async fn usage() -> Unit {
  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("echo", @jsonrpc.typed(echo))
    .build()

  let received = endpoint.receive_text(
    (
      #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
    ),
  )

  let request = endpoint.request("workspace/configuration")

  let notification = endpoint.notify("window/logMessage", params=null)

  // In an application, write these JSON values to your transport.
  ignore(received)
  ignore(request)
  ignore(notification)
}
```

Send `received.outgoing`, `request`, or `notification` through your transport.
Responses for local requests appear in `ReceiveResult.completed`.

Configuration or application-owned data can be captured by the handler.

```mbt check
///|
struct Config {
  prefix : String
}

///|
#warnings("-67")
async fn greet(config : Config, params : Json?) -> Json raise @jsonrpc.RpcError {
  guard params is Some(Object({ "name": String(name), .. })) else {
    raise @jsonrpc.invalid_params()
  }
  Json::string("\{config.prefix}, \{name}")
}

///|
pub fn configured_usage() -> Unit raise @jsonrpc.EndpointError {
  let config : Config = { prefix: "hello" }

  let endpoint = @jsonrpc.EndpointBuilder()
    .handle("greet", async fn(params) -> Json raise @jsonrpc.RpcError {
      greet(config, params)
    })
    .build()

  // Reuse the endpoint from the transport loop that drives your application.
  ignore(endpoint)
}
```

## Packages

- `shiguri-01/jsonrpc`: core endpoint
- `shiguri-01/jsonrpc/stdio`: native-only stdin/stdout transport

See [examples/README.mbt.md](examples/README.mbt.md) for runnable examples.

Spec: <https://www.jsonrpc.org/specification>
