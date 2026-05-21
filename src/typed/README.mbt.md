# Typed Params

`shiguri/jsonrpc/typed` helps keep method bodies focused on business logic by
decoding `Json?` params before the handler runs. It composes through the core
`Handler` type, so it does not add another server abstraction.

## Positional Params

Use `array1`, `array2`, or `array3` for fixed positional params.

```mbt check
///|
fn add(pair : (Double, Double)) -> Result[Json, @rpc.RpcError] {
  let (a, b) = pair
  Ok(Json::number(a + b))
}

///|
test "typed positional params" {
  let server = @rpc.Server::new()
    .register("add", handler(array2(number, number), add))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":[2,3],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Number(5.0, ..)) else {
    fail("result must be 5")
  }
}
```

## Named Params

Use `field` for required fields and `optional_field` for fields that may be
absent. `nullable(decode)` accepts JSON `null` as `None`, and otherwise returns
`Some(decoded)`.

```mbt check
///|
test "typed named params" {
  let decode = object2("left", number, "right", number)
  let handler = handler(decode, add)
  let server = @rpc.Server::new().register("add", handler).unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":{"left":4,"right":5},"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(Number(9.0, ..)) else {
    fail("result must be 9")
  }
}
```

## Scalar Decoders

`number`, `string`, and `bool` decode JSON scalar values and return
`invalid_params` errors on mismatches.
