///|
/// Handle one newline-delimited JSON-RPC input line.
///
/// Empty or whitespace-only lines produce no output. Non-empty lines are
/// dispatched as complete JSON-RPC documents. Responses include the trailing
/// newline that the stdio transport writes.
pub async fn handle_line(endpoint : @rpc.Endpoint, line : String) -> String? {
  let request = line.trim().to_owned()
  guard request != "" else { None }
  let turn = @session.Session(endpoint).receive_text(request)
  turn.response_text().map(response => "\{response}\n")
}

///|
/// Run a newline-delimited JSON-RPC stdio loop.
///
/// Each non-empty input line is treated as one complete JSON-RPC document.
/// Responses are written as one line. Notifications produce no output.
pub async fn run_lines(endpoint : @rpc.Endpoint) -> Unit {
  while @async_stdio.stdin.read_until("\n") is Some(line) {
    if handle_line(endpoint, line) is Some(response) {
      @async_stdio.stdout.write(response)
    }
  }
}
