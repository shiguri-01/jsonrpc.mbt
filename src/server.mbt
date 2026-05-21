///|
/// Transport-agnostic JSON-RPC 2.0 request dispatcher.
pub struct Server {
  priv handlers : Map[String, RawHandler]
}

///|
/// Create an empty server.
pub fn Server::new() -> Server {
  { handlers: {} }
}

///|
fn[P : @json.FromJson, R : ToJson] make_raw_handler(
  run : (P) -> Result[R, RpcError],
) -> RawHandler {
  params => {
    let decoded : P = match decode_params(params) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match run(decoded) {
      Ok(result) => Ok(result.to_json())
      Err(error) => Err(error)
    }
  }
}

///|
fn[P : @json.FromJson] decode_params(params : Json?) -> Result[P, RpcError] {
  let value = params.unwrap_or(null)
  let decoded : P = @json.from_json(value) catch {
    JsonDecodeError((path, message)) => {
      let data : Map[String, Json] = {}
      data["path"] = path.to_json()
      data["message"] = Json::string(message)
      return Err(
        RpcError::with_data(
          invalid_params_code,
          "Invalid params",
          Json::object(data),
        ),
      )
    }
  }
  Ok(decoded)
}

///|
/// Register a JSON trait method handler.
///
/// `params` are decoded using MoonBit's `FromJson` trait and handler results
/// are encoded using `ToJson`. Define request and response structs with
/// `derive(FromJson, ToJson)` to avoid writing JSON plumbing in application
/// handlers.
pub fn[P : @json.FromJson, R : ToJson] Server::register(
  self : Server,
  name : String,
  run : (P) -> Result[R, RpcError],
) -> Result[Server, RpcError] {
  self.register_raw(name, make_raw_handler(run))
}

///|
/// Register a low-level JSON method handler.
///
/// JSON-RPC reserves method names that start with `rpc.` for extensions, so this
/// helper rejects them early. This is a builder-style operation: the returned
/// `Server` contains the new handler, while the original `Server` is unchanged.
pub fn Server::register_raw(
  self : Server,
  name : String,
  handler : RawHandler,
) -> Result[Server, RpcError] {
  if name.has_prefix("rpc.") {
    return Err(
      RpcError::new(
        invalid_request_code, "Method names starting with rpc. are reserved",
      ),
    )
  }
  if self.handlers.get(name) is Some(_) {
    return Err(RpcError::new(invalid_request_code, "Method already registered"))
  }
  let handlers = self.handlers.copy()
  handlers[name] = handler
  Ok({ handlers, })
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
    Err(error) =>
      return Some(error_response(error.id.unwrap_or(null), error.error))
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
