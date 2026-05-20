# Typed Params

`shiguri/jsonrpc/typed` helps keep method bodies focused on business logic by
decoding `Json?` params before the handler runs. It composes through the core
`Handler` type, so it does not add another server abstraction.

## Positional Params

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
