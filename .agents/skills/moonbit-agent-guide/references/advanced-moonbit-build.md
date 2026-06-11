## Conditional Compilation

Target specific backends/modes in `moon.pkg`:

```
options(
  targets: {
    "wasm_only.mbt": ["wasm"],
    "js_only.mbt": ["js"],
    "debug_only.mbt": ["debug"],
    "wasm_or_js.mbt": ["wasm", "js"], // for wasm or js backend
    "not_js.mbt": ["not", "js"], // for nonjs backend
    "complex.mbt": ["or", ["and", "wasm", "release"], ["and", "js", "debug"]] // more complex conditions
  }
)
```

**Available conditions:**

- **Backends**: `"wasm"`, `"wasm-gc"`, `"js"`, `"native"`
- **Build modes**: `"debug"`, `"release"`
- **Logical operators**: `"and"`, `"or"`, `"not"`

## Link Configuration

### Basic Linking

```
options(
  link: true, // Enable linking for this package
)
```

For advanced cases:

```
options(
  link: {
    "wasm": {
      "exports": ["hello", "foo:bar"], // Export functions
      "heap-start-address": 1024, // Memory layout
      "import-memory": {
        // Import external memory
        "module": "env",
        "name": "memory"
      },
      "export-memory-name": "memory" // Export memory with name
    },
    "wasm-gc": {
      "exports": ["hello"],
      "use-js-builtin-string": true, // JS String Builtin support
      "imported-string-constants": "_" // String namespace
    },
    "js": {
      "exports": ["hello"],
      "format": "esm" // "esm", "cjs", or "iife"
    },
    "native": {
      "cc": "gcc", // C compiler
      "cc-flags": "-O2 -DMOONBIT", // Compile flags
      "cc-link-flags": "-s" // Link flags
    }
  }
)
```

## Warning Control

Disable specific warnings in `moon.mod` or `moon.pkg`:

```
warnings = "-2-29" // Disable unused variable (2) & unused package (29)
```

**Common warning numbers:**

- `1` - Unused function
- `2` - Unused variable
- `11` - Partial pattern matching
- `12` - Unreachable code
- `29` - Unused package

Use `moonc check -warn-help` to see all available warnings.

## Dev Build Commands

Embed external files as MoonBit code:

```
rule(name: "embed", command: ":embed -i $input -o $output --name data --text")
dev_build(rule: "embed", input: "data.txt", output: "embedded.mbt")
```

Generated code example:

```mbt check
///|
let data : String =
  #|hello,
  #|world
  #|
```
