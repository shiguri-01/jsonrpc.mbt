///|
fn stringify_outgoing(outgoing : Array[Json]) -> String? {
  match outgoing {
    [] => None
    [item] => Some(item.stringify())
    items => Some(Json::array(items).stringify())
  }
}

///|
/// Handle one newline-delimited JSON-RPC input line.
///
/// Empty or whitespace-only lines produce no output. Non-empty lines are
/// dispatched as complete JSON-RPC documents. Responses include the trailing
/// newline that the stdio transport writes.
pub async fn handle_line(endpoint : @rpc.Endpoint, line : String) -> String? {
  let request = line.trim().to_owned()
  if request == "" {
    None
  } else {
    let result = endpoint.receive_text(request)
    stringify_outgoing(result.outgoing).map(response => "\{response}\n")
  }
}

///|
/// Run a newline-delimited JSON-RPC stdio loop.
///
/// Each non-empty input line is treated as one complete JSON-RPC document.
/// Responses are written as one line. Notifications produce no output.
pub async fn run_lines(endpoint : @rpc.Endpoint) -> Unit {
  while @async_stdio.stdin.read_until("\n") is Some(line) {
    match handle_line(endpoint, line) {
      Some(response) => @async_stdio.stdout.write(response)
      None => ()
    }
  }
}
