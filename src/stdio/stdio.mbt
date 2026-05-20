///|
/// Run a newline-delimited JSON-RPC stdio loop.
///
/// Each non-empty input line is treated as one complete JSON-RPC document.
/// Responses are written as one line. Notifications produce no output.
pub async fn run_lines(server : @rpc.Server) -> Unit {
  while @async_stdio.stdin.read_until("\n") is Some(line) {
    let request = line.trim().to_owned()
    if request != "" {
      match server.handle_text(request) {
        Some(response) => @async_stdio.stdout.write("\{response}\n")
        None => ()
      }
    }
  }
}
