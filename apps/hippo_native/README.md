# HippoNative (Rust / Rustler)

`HippoNative` is a deterministic statistical engine exposed to Elixir via Rustler NIFs (Native Implemented Functions). It offloads the CPU-intensive math required for anomaly detection.

## Core Algorithm: Welford's Online Algorithm
To calculate variance and standard deviation on a continuous, infinite stream of data, standard mathematical formulas suffer from catastrophic floating-point precision loss. We use **Welford's Online Algorithm** to calculate a highly stable, running variance without needing to store the entire history of the stream.

* **Warm-up Phase:** The algorithm requires a minimum of 50 ticks (`count > 50`) before the Z-score can be considered mathematically significant.

## Rustler NIF Integration
* **Module:** `Elixir.HippoNative.Native`
* **State Passing:** Because Elixir variables are immutable, the Rust NIF does not maintain its own background state. Instead, it defines a `WelfordState` struct. Elixir passes this struct into the NIF on every tick, and the NIF returns a *new* mutated struct back to Elixir.
* **Compilation:** Managed automatically by `Rustler` during `mix compile`. (Note: Ensure the Docker volume shields are active to prevent macOS ARM binaries from crashing the Linux container).