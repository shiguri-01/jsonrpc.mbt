# Design Notes

This library should model JSON-RPC as a bidirectional protocol endpoint, not
only as a one-way server.

## Core Model

The central public type is `Endpoint`.

An `Endpoint` represents one side of a JSON-RPC connection. It can receive
requests, notifications, and responses from the remote side. It can also create
outgoing requests and notifications.

Transport is outside the core model. The endpoint works with JSON values or text
messages, while stdio, WebSocket, HTTP, and other runtime boundaries are adapter
layers.

```text
Transport
  stdio / WebSocket / HTTP / tests

Codec
  text <-> JSON

Protocol
  JSON <-> JSON-RPC messages

Endpoint
  handler dispatch
  outgoing request id generation
  pending response tracking
```

## Endpoint

`Endpoint` owns runtime state.

It contains a fixed method table plus mutable protocol state such as the next
request id and pending outgoing requests.

```text
Endpoint
  router : Router
  mut next_id : Int
  mut pending : Map[Id, Pending]
```

This is intentional. A bidirectional JSON-RPC endpoint is stateful by nature.
Keeping runtime state inside `Endpoint` gives users a simple object to drive from
a transport loop.

Configuration and method registration happen before the endpoint is used. Runtime
operations mutate the endpoint.

```text
build/configure: immutable builder style
run protocol: mutable endpoint state
```

## Builder

Methods are registered through `EndpointBuilder`.

```mbt
let endpoint = EndpointBuilder()
  .handle("echo", echo)
  .handle("subtract", subtract)
  .build()
```

`EndpointBuilder` should use a MoonBit custom constructor instead of a
`EndpointBuilder::new()` method. The constructor call `EndpointBuilder()` starts
method registration and returns an `EndpointBuilder`.

Do not use an `Endpoint::new` method or constructor to start registration. If an
`Endpoint` constructor exists, it should create an already usable `Endpoint`, not
an `EndpointBuilder`.

`build()` is the final builder operation. It creates the runtime `Endpoint`.

## Handler Shape

`EndpointBuilder` registers one kind of handler.

```mbt
type Handler = (Json?) -> Json raise RpcError
```

This is the protocol-level shape. JSON-RPC `params` may be absent, positional,
or named, and MoonBit's `Json` values are convenient to inspect directly with
`match` and `guard`.

Registration stays simple.

```mbt
let endpoint = EndpointBuilder()
  .handle("echo", echo)
  .build()
```

Typed params and results are still important, but they should be expressed as
ordinary handler adapters instead of as a second registration path.

```mbt
fn typed[P : FromJson, R : ToJson](
  f : (P) -> R raise RpcError
) -> Handler
```

With this shape, a typed method is registered by first adapting it into a
`Handler`.

```mbt
let endpoint = EndpointBuilder()
  .handle("add", typed(add))
  .build()
```

`FromJson` and `ToJson` are trait bounds, not a requirement to use derived JSON
implementations. Simple structs can use `derive`, while methods with a more
specific wire shape can implement the traits manually or operate on `Json`
directly.

The typed adapter is part of the public API. It preserves the convenience of
typed params and results without adding a second registration method.

Application state is not part of the core endpoint type. If handlers need shared
state, bind it outside the core with a closure or a small handler adapter.

```mbt
let endpoint = EndpointBuilder()
  .handle("definition", bind(workspace, definition))
  .build()
```

This keeps `Endpoint` focused on JSON-RPC protocol state. Context remains an
application-level concern instead of becoming a generic parameter of every
endpoint and handler.

Typed conversion, context binding, logging, validation, and similar behavior
should compose as ordinary functions that produce or transform `Handler` values.
Do not introduce a middleware framework unless ordinary function composition is
not enough.

## Errors

The core handler boundary uses `raise`.

```mbt
type Handler = (Json?) -> Json raise RpcError
```

`RpcError` is a JSON-RPC protocol error value. Raising `RpcError` from a handler
means the endpoint should send a JSON-RPC error response for requests with an id.

`RpcError` should be a MoonBit error type with labeled payloads. Use
`RpcError(code=..., message=...)` when there is no `data` member, and
`RpcErrorWithData(code=..., message=..., data=...)` when the JSON-RPC error
should include `data`.

MoonBit `raise` is used at the handler boundary, but only for errors that should
cross the JSON-RPC protocol boundary as `RpcError`.

Examples:

- JSON decode failures in typed adapters become `invalid_params`.
- Parse failures become JSON-RPC parse error responses.
- Internal failures that should be visible to the peer become `internal_error`.
- Transport/runtime failures remain outside the core protocol handler model.

This keeps JSON-RPC errors as normal protocol data instead of mixing them with
MoonBit runtime errors.

Local endpoint misuse and construction failures use a separate `EndpointError`
instead of `RpcError`. For example, `request(..., id=...)` fails with
`EndpointError` when the explicit id already exists in `pending`. Invalid or
reserved method names should also be reported as `EndpointError`.

## Ids

Use a dedicated `Id` type for request correlation instead of storing ids as
plain `Json`.

```text
Id
  String(String)
  Number(Int)
```

`Endpoint` generates numeric ids for outgoing requests. Users may provide either
a string or integer id explicitly with `request(..., id=...)`.

`Id` should use its enum constructors directly, and JSON conversion should be
implemented through `ToJson` and, where useful, `FromJson`. Do not add
constructor helpers such as `Id::string`.

`Id` intentionally does not include `null`. Although JSON-RPC allows `id: null`
in received requests, `null` is awkward as a local pending-request key and is not
used for ids generated by this endpoint. Incoming request ids that are `null`
must still be preserved when sending a response, but they do not become pending
correlation ids.

Responses whose ids do not match `pending`, including `id: null`, are reported
as unexpected responses.

## Receive Flow

Receiving input produces protocol effects.

Incoming requests may produce outgoing responses. Incoming responses may complete
previously sent local requests. Notifications may run handlers but do not produce
responses.

The receive API should expose these effects explicitly.

```text
ReceiveResult
  outgoing : Array[Json]
  completed : Array[CompletedRequest]
  unexpected : Array[Json]

CompletedRequest
  id : Id
  method_name : String
  result : Result[Json, RpcError]
```

`outgoing` contains JSON-RPC messages that the transport should send to the
remote side.

`completed` contains results or errors for requests previously created by this
endpoint. It uses MoonBit's built-in `Result` instead of a custom response enum:
JSON-RPC result responses become `Ok(json)`, and JSON-RPC error responses become
`Err(error)`.

`unexpected` contains response messages that cannot be matched to a pending
request. JSON-RPC responses do not receive responses, so the endpoint should not
append anything to `outgoing` for these messages, but users should still be able
to observe them.

## Sending Requests

The endpoint is responsible for assigning ids and tracking pending requests.

```mbt
Endpoint::request(method_name : String, params? : Json, id? : Id) -> Result[Json, EndpointError]
Endpoint::notify(method_name : String, params? : Json) -> Result[Json, EndpointError]
```

`request` assigns an id by default and records it in `pending`. A later response
with the same id completes that request.

Users can provide an explicit id with the labeled optional `id` argument.

```mbt
endpoint.request("workspace/configuration", params=params)
endpoint.request("workspace/configuration", params=params, id=Id::String("abc"))
```

Do not add separate `request_with_id`-style methods. Optional and labeled
parameters are the extension point for request construction options.

If an explicit id is already present in `pending`, `request` returns
`Err(EndpointError::DuplicatePendingId(...))`.

`params? : Json` preserves the JSON-RPC distinction between an absent `params`
member and a present `params: null` member.

`notify` does not allocate pending state because JSON-RPC notifications do not
receive responses. It still returns `Result` because it performs the same local
message construction and method validation as `request`.

## Batches

JSON-RPC batches are part of the protocol, so the core handles them.

`receive_json` accepts either a single JSON-RPC message or a JSON array batch.
When receiving a batch, the endpoint processes items in order and accumulates one
`ReceiveResult`.

- Request responses are appended to `outgoing`.
- Notifications append no response.
- Responses to locally sent requests are appended to `completed`.
- Responses that do not match `pending` are appended to `unexpected`.
- Empty batches produce the JSON-RPC invalid request response.

For outgoing batches, individual calls to `request` and `notify` create JSON
messages. Users can group those messages with `Json::array` or a small `batch`
helper.

```mbt
let one = endpoint.request("one").unwrap()
let two = endpoint.notify("two").unwrap()
let doc = batch([one, two])
```

No separate batch builder is needed initially.

## One-Way Server Use

A one-way JSON-RPC server is just an endpoint that never calls `request`.

It only receives remote requests and notifications, then sends the resulting
responses from `ReceiveResult.outgoing`.

No compatibility `Server` layer is required. The name `Endpoint` should remain
the public concept for both one-way and bidirectional use.

## Package Shape

The code should be organized around protocol responsibilities.

```text
src/
  error.mbt       RpcError and standard JSON-RPC error codes
  message.mbt     Request, Notification, Response, Message, Id
  codec.mbt       parsing and stringifying JSON-RPC messages
  router.mbt      method table and handler dispatch
  endpoint.mbt    bidirectional endpoint state and orchestration
  stdio/          native stdio transport adapter
```

File names are organizational only. The package should still present a small
public surface centered on `Endpoint`, `EndpointBuilder`, `RpcError`, and message
result types.

## Design Principle

The library should stay small and protocol-focused.

It should provide a typed MoonBit interface for JSON-RPC methods, keep transport
outside the core, and make the statefulness of bidirectional JSON-RPC explicit in
`Endpoint`.
