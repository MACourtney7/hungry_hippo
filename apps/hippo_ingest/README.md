# HippoIngest (Elixir / OTP)

`HippoIngest` is the orchestration layer of the HungryHippo pipeline. It is responsible for consuming raw streams, maintaining chronological state, coordinating with the Rust NIF for mathematical evaluation, and handling HTTP fallback logic.

## OTP Architecture & State Management
* **`HippoIngest.Pipeline.Broadway`**: The Kafka consumer. Subscribes to `raw_market_ticks`. It parses the JSON and routes ticks to specific GenServers based on the `feed_id` partition key.
* **`HippoIngest.FeedRegistry`**: A dynamic `Registry` used to look up the GenServer PID for a specific `feed_id`.
* **`HippoIngest.WindowWorker` (GenServer)**: The core state manager.
  * Maintains a strict **50-tick chronological buffer** (`state.buffer`).
  * Maintains the **Rust Welford State** (`state.welford`).
  * On every tick, it updates the NIF. If Z-Score > 3.0, it triggers the `call_oracle/2` HTTP POST request.
  * **Fail-Open Design:** If the Oracle HTTP call fails, times out, or returns a non-200 status, the GenServer logs the error and returns the *raw* tick to prevent halting the stream.

## Telemetry & Egress
All metrics are emitted via `:telemetry.execute/3` and scraped by Prometheus. Egress to the `clean_market_ticks` Kafka topic is handled synchronously via `:brod.produce_sync` to guarantee ordering and data integrity.