# NIF for HippoNative.Native

This module provides a Native Implemented Function (NIF) for the `HippoNative` Elixir application, leveraging Rust for high-performance statistical analysis within the HungryHippo project. It uses `Rustler` to seamlessly integrate Rust code with Elixir.

## Building the NIF Module

The Rust NIF module is built automatically as part of your Elixir project's compilation process, thanks to the `Rustler` library. Ensure you have a Rust toolchain installed.

To build the project, including the NIF, you can run:
```bash
mix compile
```

## To load the NIF:

```elixir
defmodule HippoNative.Native do
  use Rustler, otp_app: :hippo_native, crate: "hippo_native"
  # When your NIF is loaded, it will override this function.
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)
end
```

## Examples

[This](https://github.com/rusterlium/NifIo) is a complete example of a NIF written in Rust.
