defmodule HippoNative.Native do
  use Rustler, otp_app: :hippo_native, crate: "hippo_native"

  # Stubs for the Rust functions. These will be overridden by the NIF loading.
  
  def init_state(), do: :erlang.nif_error(:nif_not_loaded)
  
  def update_and_get_z_score(_state, _new_value), do: :erlang.nif_error(:nif_not_loaded)
end
