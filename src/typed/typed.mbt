///|
/// Decode JSON-RPC params into an application-specific value.
pub type Decoder[A] = (Json?) -> Result[A, @rpc.RpcError]

///|
/// Build a JSON-RPC handler from a params decoder and typed function.
pub fn[A] handler(
  decode : Decoder[A],
  run : (A) -> Result[Json, @rpc.RpcError],
) -> @rpc.Handler {
  params => {
    match decode(params) {
      Ok(value) => run(value)
      Err(error) => Err(error)
    }
  }
}

///|
/// Require the `params` member and decode the raw JSON value.
pub fn[A] params(decode : (Json) -> Result[A, @rpc.RpcError]) -> Decoder[A] {
  params => {
    match params {
      Some(value) => decode(value)
      None => Err(@rpc.invalid_params(message="Missing params"))
    }
  }
}

///|
/// Decode params as an array with two values.
pub fn[A, B] array2(
  first : (Json) -> Result[A, @rpc.RpcError],
  second : (Json) -> Result[B, @rpc.RpcError],
) -> Decoder[(A, B)] {
  params => {
    match params {
      Some(Array([a, b])) =>
        match (first(a), second(b)) {
          (Ok(a), Ok(b)) => Ok((a, b))
          (Err(error), _) | (_, Err(error)) => Err(error)
        }
      _ => Err(@rpc.invalid_params(message="Expected two positional params"))
    }
  }
}

///|
/// Decode a JSON number.
pub fn number(value : Json) -> Result[Double, @rpc.RpcError] {
  match value {
    Number(value, ..) => Ok(value)
    _ => Err(@rpc.invalid_params(message="Expected number"))
  }
}

///|
/// Decode a JSON string.
pub fn string(value : Json) -> Result[String, @rpc.RpcError] {
  match value {
    String(value) => Ok(value)
    _ => Err(@rpc.invalid_params(message="Expected string"))
  }
}

///|
/// Decode a JSON object field.
pub fn[A] field(
  name : String,
  decode : (Json) -> Result[A, @rpc.RpcError],
) -> (Map[String, Json]) -> Result[A, @rpc.RpcError] {
  obj => {
    match obj.get(name) {
      Some(value) => decode(value)
      None => Err(@rpc.invalid_params(message="Missing field: \{name}"))
    }
  }
}

///|
/// Decode params as an object with two named fields.
pub fn[A, B] object2(
  first_name : String,
  first : (Json) -> Result[A, @rpc.RpcError],
  second_name : String,
  second : (Json) -> Result[B, @rpc.RpcError],
) -> Decoder[(A, B)] {
  params => {
    match params {
      Some(Object(obj)) =>
        match (field(first_name, first)(obj), field(second_name, second)(obj)) {
          (Ok(a), Ok(b)) => Ok((a, b))
          (Err(error), _) | (_, Err(error)) => Err(error)
        }
      _ => Err(@rpc.invalid_params(message="Expected named params"))
    }
  }
}
