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
/// Decode params as an array with one value.
pub fn[A] array1(first : (Json) -> Result[A, @rpc.RpcError]) -> Decoder[A] {
  params => {
    match params {
      Some(Array([a])) => first(a)
      _ => Err(@rpc.invalid_params(message="Expected one positional param"))
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
/// Decode params as an array with three values.
pub fn[A, B, C] array3(
  first : (Json) -> Result[A, @rpc.RpcError],
  second : (Json) -> Result[B, @rpc.RpcError],
  third : (Json) -> Result[C, @rpc.RpcError],
) -> Decoder[(A, B, C)] {
  params => {
    match params {
      Some(Array([a, b, c])) =>
        match (first(a), second(b), third(c)) {
          (Ok(a), Ok(b), Ok(c)) => Ok((a, b, c))
          (Err(error), _, _) | (_, Err(error), _) | (_, _, Err(error)) =>
            Err(error)
        }
      _ => Err(@rpc.invalid_params(message="Expected three positional params"))
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
/// Decode a JSON boolean.
pub fn boolean(value : Json) -> Result[Bool, @rpc.RpcError] {
  match value {
    True => Ok(true)
    False => Ok(false)
    _ => Err(@rpc.invalid_params(message="Expected boolean"))
  }
}

///|
/// Decode a JSON boolean.
pub fn bool(value : Json) -> Result[Bool, @rpc.RpcError] {
  boolean(value)
}

///|
/// Decode JSON null as `None`, or decode a present value as `Some`.
pub fn[A] nullable(
  decode : (Json) -> Result[A, @rpc.RpcError],
) -> (Json) -> Result[A?, @rpc.RpcError] {
  value => {
    match value {
      Null => Ok(None)
      _ =>
        match decode(value) {
          Ok(value) => Ok(Some(value))
          Err(error) => Err(error)
        }
    }
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
/// Decode an optional JSON object field.
///
/// Missing fields decode as `None`. Present fields, including explicit `null`,
/// are passed to the supplied decoder.
pub fn[A] optional_field(
  name : String,
  decode : (Json) -> Result[A, @rpc.RpcError],
) -> (Map[String, Json]) -> Result[A?, @rpc.RpcError] {
  obj => {
    match obj.get(name) {
      Some(value) =>
        match decode(value) {
          Ok(value) => Ok(Some(value))
          Err(error) => Err(error)
        }
      None => Ok(None)
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
