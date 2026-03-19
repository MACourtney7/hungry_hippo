# Hippo Producer (Python / Kafka)

The Producer is a standalone script designed to stress-test the HungryHippo pipeline by simulating a high-throughput, chaotic market data feed.

## Data Simulation Profile
* **Asset:** Simulates Bitcoin (BTC/USD) starting around a baseline of $65,000.
* **Tick Rate:** Emits 1 tick every 100 milliseconds (10 ticks per second) to the `raw_market_ticks` Kafka topic.
* **Standard Volatility:** Uses a random walk algorithm to simulate normal, minor market fluctuations between ticks.

## Anomaly Injection Logic
To trigger the Elixir/Rust anomaly detection engine, the Producer intentionally sabotages its own data stream.
* **Frequency:** Approximately 1% of the time (determined probabilistically).
* **Magnitude:** Injects a massive 5% spike or crash into the current price.
* **Purpose:** This guarantees that the Rust NIF's Welford algorithm will generate a Z-score > 3.0, forcing Elixir to pause the stream and consult the AI Oracle for correction.

## Environment Constraints
* Relies on the `kafka-python` library.
* Must wait for the Kafka broker (KRaft mode) to be fully healthy before attempting to connect and publish.