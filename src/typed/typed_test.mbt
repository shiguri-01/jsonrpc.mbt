///|
fn add_pair(pair : (Double, Double)) -> Result[Json, @rpc.RpcError] {
  let (a, b) = pair
  Ok(Json::number(a + b))
}

///|
fn echo_bool(value : Bool) -> Result[Json, @rpc.RpcError] {
  Ok(Json::boolean(value))
}

///|
fn join_triple(values : (String, Double, Bool)) -> Result[Json, @rpc.RpcError] {
  let (name, count, active) = values
  let obj : Map[String, Json] = {}
  obj["name"] = Json::string(name)
  obj["count"] = Json::number(count)
  obj["active"] = Json::boolean(active)
  Ok(Json::object(obj))
}

///|
test "typed handler decodes positional params" {
  let server = @rpc.Server::new()
    .register("add", handler(array2(number, number), add_pair))
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

///|
test "typed handler returns invalid params from decoder" {
  let server = @rpc.Server::new()
    .register("add", handler(array2(number, number), add_pair))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"add","params":["x",3],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("error") is Some(Object(error)) else {
    fail("response must include error")
  }
  guard error.get("code") is Some(Number(-32602.0, ..)) else {
    fail("error code must be invalid params")
  }
}

///|
test "array1 decodes one positional boolean param" {
  let server = @rpc.Server::new()
    .register("echo", handler(array1(bool), echo_bool))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"echo","params":[true],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(obj) else { fail("response must be object") }
  guard obj.get("result") is Some(True) else { fail("result must be true") }
}

///|
test "array3 decodes three positional params" {
  let server = @rpc.Server::new()
    .register("join", handler(array3(string, number, boolean), join_triple))
    .unwrap()
  let request =
    #|{"jsonrpc":"2.0","method":"join","params":["jobs",3,true],"id":1}
  let response = server.handle_text(request)
  guard response is Some(text) else { fail("expected response") }
  let json = @json.parse(text) catch { _ => fail("response must be JSON") }
  guard json is Object(response_obj) else { fail("response must be object") }
  guard response_obj.get("result") is Some(Object(result)) else {
    fail("result must be object")
  }
  guard result.get("name") is Some(String("jobs")) else {
    fail("name must decode")
  }
  guard result.get("count") is Some(Number(3.0, ..)) else {
    fail("count must decode")
  }
  guard result.get("active") is Some(True) else { fail("active must decode") }
}

///|
test "nullable decodes null as none and present value as some" {
  match nullable(number)(null) {
    Ok(None) => ()
    _ => fail("null must decode as None")
  }
  match nullable(number)(Json::number(42.0)) {
    Ok(Some(42.0)) => ()
    _ => fail("number must decode as Some")
  }
  match nullable(number)(Json::string("x")) {
    Err(error) => {
      let code = error.code
      guard code == @rpc.invalid_params_code else {
        fail("invalid nullable value must be invalid params")
      }
    }
    _ => fail("invalid nullable value must fail")
  }
}

///|
test "optional_field decodes missing and present object fields" {
  let obj : Map[String, Json] = {}
  obj["limit"] = Json::number(10.0)
  match optional_field("missing", number)(obj) {
    Ok(None) => ()
    _ => fail("missing optional field must decode as None")
  }
  match optional_field("limit", number)(obj) {
    Ok(Some(10.0)) => ()
    _ => fail("present optional field must decode as Some")
  }
  obj["limit"] = Json::string("many")
  match optional_field("limit", number)(obj) {
    Err(error) => {
      let code = error.code
      guard code == @rpc.invalid_params_code else {
        fail("invalid optional field must be invalid params")
      }
    }
    _ => fail("invalid optional field must fail")
  }
}
