///|
/// Transport-agnostic JSON-RPC 2.0 request dispatcher.
pub struct Server {
  handlers : Map[String, Handler]
}

///|
/// Create an empty server.
pub fn Server::new() -> Server {
  { handlers: {} }
}

///|
/// Register a method handler.
///
/// JSON-RPC reserves method names that start with `rpc.` for extensions, so this
/// helper rejects them early.
pub fn Server::register(
  self : Server,
  name : String,
  handler : Handler,
) -> Result[Server, RpcError] {
  if name.has_prefix("rpc.") {
    return Err(
      RpcError::new(
        invalid_request_code, "Method names starting with rpc. are reserved",
      ),
    )
  }
  self.handlers[name] = handler
  Ok(self)
}

///|
/// Handle a raw JSON document.
///
/// Returns `None` for notifications and notification-only batches.
pub fn Server::handle_text(self : Server, input : String) -> String? {
  let value = @json.parse(input) catch {
    _ =>
      return Some(
        unknown_id_error(RpcError::new(parse_error_code, "Parse error")).stringify(),
      )
  }
  self.handle_json(value).map(response => response.stringify())
}

///|
/// Handle an already parsed JSON value.
pub fn Server::handle_json(self : Server, value : Json) -> Json? {
  match value {
    Array(items) => self.handle_batch(items)
    item => self.handle_one(item)
  }
}

///|
fn Server::handle_batch(self : Server, items : Array[Json]) -> Json? {
  if items.is_empty() {
    return Some(
      unknown_id_error(RpcError::new(invalid_request_code, "Invalid Request")),
    )
  }
  let responses : Array[Json] = []
  for item in items {
    if self.handle_one(item) is Some(response) {
      responses.push(response)
    }
  }
  if responses.is_empty() {
    None
  } else {
    Some(Json::array(responses))
  }
}

///|
fn Server::handle_one(self : Server, value : Json) -> Json? {
  let request = match parse_request(value) {
    Ok(request) => request
    Err(error) => return Some(unknown_id_error(error))
  }
  let id = request.id.unwrap_or(null)
  let handler = match self.handlers.get(request.rpc_method) {
    Some(handler) => handler
    None =>
      if request.notification {
        return None
      } else {
        return Some(
          error_response(
            id,
            RpcError::new(method_not_found_code, "Method not found"),
          ),
        )
      }
  }
  match handler(request.params) {
    Ok(result) =>
      if request.notification {
        None
      } else {
        Some(success_response(id, result))
      }
    Err(error) =>
      if request.notification {
        None
      } else {
        Some(error_response(id, error))
      }
  }
}
