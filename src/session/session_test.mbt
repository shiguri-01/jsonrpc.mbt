///|
#warnings("-unused_async-unused_error_type")
async fn echo(params : Json?) -> Json raise @rpc.RpcError {
  params.unwrap_or(null)
}

///|
fn test_session() -> Session raise @rpc.EndpointError {
  let endpoint = @rpc.EndpointBuilder().handle("echo", echo).build()
  Session(endpoint)
}

///|
async test "receive_text exposes one response document" {
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"},"id":1}
  let turn = test_session().receive_text(input)
  guard turn.outgoing() is [Object(response)] else {
    fail("turn must expose one outgoing response")
  }
  guard response.get("result") is Some(Object(result)) else {
    fail("response must include result")
  }
  guard result.get("message") is Some(String("hello")) else {
    fail("result must preserve params")
  }
  guard turn.response_json() is Some(Object(_)) else {
    fail("single response must stay an object")
  }
  guard turn.response_text() is Some(text) else {
    fail("single response must stringify")
  }
  guard text.has_prefix("{") else { fail("response text must be JSON object") }
}

///|
async test "receive_text batches multiple response documents" {
  let input =
    #|[
    #|  {"jsonrpc":"2.0","method":"echo","params":{"message":"one"},"id":1},
    #|  {"jsonrpc":"2.0","method":"missing","id":2}
    #|]
  let turn = test_session().receive_text(input)
  guard turn.outgoing().length() == 2 else {
    fail("turn must expose two outgoing responses")
  }
  guard turn.response_json() is Some(Array([Object(first), Object(second)])) else {
    fail("multiple responses must become a batch response")
  }
  guard first.get("result") is Some(Object(_)) else {
    fail("first response must include result")
  }
  guard second.get("error") is Some(Object(error)) else {
    fail("second response must include error")
  }
  guard error.get("code") is Some(Number(-32601.0, ..)) else {
    fail("second response must be method not found")
  }
}

///|
async test "receive_text preserves batch framing for one response" {
  let input =
    #|[
    #|  {"jsonrpc":"2.0","method":"echo","params":{"message":"one"},"id":1},
    #|  {"jsonrpc":"2.0","method":"echo","params":{"message":"notice"}}
    #|]
  let turn = test_session().receive_text(input)
  guard turn.outgoing() is [Object(response)] else {
    fail("turn must expose one outgoing response")
  }
  guard response.get("result") is Some(Object(result)) else {
    fail("response must include result")
  }
  guard result.get("message") is Some(String("one")) else {
    fail("result must preserve params")
  }
  guard turn.response_json() is Some(Array([Object(batch_response)])) else {
    fail("single batch response must stay wrapped in an array")
  }
  guard batch_response.get("result") is Some(Object(_)) else {
    fail("batch response must include result")
  }
  guard turn.response_text() is Some(text) else {
    fail("batch response must stringify")
  }
  guard text.has_prefix("[") else {
    fail("batch response text must be JSON array")
  }
}

///|
async test "notifications produce no response text" {
  let input =
    #|{"jsonrpc":"2.0","method":"echo","params":{"message":"hello"}}
  let turn = test_session().receive_text(input)
  guard turn.outgoing().is_empty() else {
    fail("notification must not produce outgoing responses")
  }
  guard turn.response_json() is None else {
    fail("notification must not produce response json")
  }
  guard turn.response_text() is None else {
    fail("notification must not produce response text")
  }
}

///|
async test "request completion is surfaced through turn" {
  let session = test_session()
  let request = session.request("echo", params={ "message": "hello" })
  guard request is Object(request_obj) else {
    fail("request must be an object")
  }
  guard request_obj.get("id") is Some(id) else {
    fail("request must include an id")
  }
  let response : Json = { "jsonrpc": "2.0", "id": id, "result": { "ok": true } }
  let turn = session.receive_json(response)
  guard turn.completed() is [completed] else {
    fail("response must complete the pending request")
  }
  guard completed.method_name == "echo" else {
    fail("completed method name must be preserved")
  }
  guard completed.result is Ok(Object(result)) else {
    fail("completed result must be available")
  }
  guard result.get("ok") is Some(true) else {
    fail("completed result must preserve response")
  }
}
