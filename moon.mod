name = "shiguri-01/jsonrpc"

version = "0.2.0"

import {
  "moonbitlang/async@0.19.3",
}

readme = "README.mbt.md"

repository = "https://github.com/shiguri-01/jsonrpc.mbt"

license = "Apache-2.0"

keywords = [ "json-rpc", "jsonrpc", "rpc", "endpoint" ]

description = "A small, transport-agnostic JSON-RPC 2.0 endpoint library."

preferred_target = "native"

options(
  source: "src",
  exclude: [ "examples", "flake.nix", "flake.lock", "nix" ],
)
