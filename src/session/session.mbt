///|
/// Optional transport-neutral JSON-RPC session helper.
///
/// A session owns no transport. It accepts complete JSON-RPC documents and
/// returns the JSON documents that should be written back by the caller.
pub struct Session {
  priv endpoint : @rpc.Endpoint
}

///|
/// Create a session around an endpoint.
pub fn Session::Session(endpoint : @rpc.Endpoint) -> Session {
  { endpoint, }
}

///|
/// Access the wrapped endpoint for lower-level operations.
pub fn Session::endpoint(self : Self) -> @rpc.Endpoint {
  self.endpoint
}

///|
/// Create a JSON-RPC request and register it as pending.
pub fn Session::request(
  self : Self,
  rpc_method : String,
  params? : Json,
  id? : @rpc.Id,
) -> Json raise @rpc.EndpointError {
  self.endpoint.request(rpc_method, params?, id?)
}

///|
/// Create a JSON-RPC notification.
pub fn Session::notify(
  self : Self,
  rpc_method : String,
  params? : Json,
) -> Json raise @rpc.EndpointError {
  self.endpoint.notify(rpc_method, params?)
}

///|
/// Handle one complete JSON-RPC text document.
pub async fn Session::receive_text(self : Self, text : String) -> Turn {
  try @json.parse(text) catch {
    _ => Turn::from_result(self.endpoint.receive_text(text))
  } noraise {
    value => Turn::from_json_result(value, self.endpoint.receive_json(value))
  }
}

///|
/// Handle one complete JSON-RPC JSON value.
pub async fn Session::receive_json(self : Self, value : Json) -> Turn {
  Turn::from_json_result(value, self.endpoint.receive_json(value))
}

///|
/// Result of one receive turn.
pub struct Turn {
  priv result : @rpc.ReceiveResult
  priv response_batch : Bool
} derive(Eq, Debug)

///|
fn Turn::from_result(result : @rpc.ReceiveResult) -> Turn {
  { result, response_batch: false }
}

///|
fn Turn::from_json_result(value : Json, result : @rpc.ReceiveResult) -> Turn {
  {
    result,
    response_batch: match value {
      Array(items) => !items.is_empty()
      _ => false
    },
  }
}

///|
/// Access the underlying endpoint receive result.
pub fn Turn::result(self : Self) -> @rpc.ReceiveResult {
  self.result
}

///|
/// JSON-RPC documents that should be written back by the transport.
pub fn Turn::outgoing(self : Self) -> Array[Json] {
  self.result.outgoing
}

///|
/// Locally issued requests completed by this receive turn.
pub fn Turn::completed(self : Self) -> Array[@rpc.CompletedRequest] {
  self.result.completed
}

///|
/// Response-like documents that did not match a pending request.
pub fn Turn::unexpected(self : Self) -> Array[Json] {
  self.result.unexpected
}

///|
/// Convert outgoing response documents into one JSON-RPC response document.
///
/// Returns `None` when no response should be sent. Non-empty input batches keep
/// batch framing whenever at least one response exists.
pub fn Turn::response_json(self : Self) -> Json? {
  match self.result.outgoing {
    [] => None
    items if self.response_batch => Some(@rpc.batch(items))
    [item] => Some(item)
    items => Some(@rpc.batch(items))
  }
}

///|
/// Convert outgoing response documents into JSON text.
pub fn Turn::response_text(self : Self) -> String? {
  self.response_json().map(fn(value) { value.stringify() })
}
