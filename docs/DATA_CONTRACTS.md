# HungryHippo Data Contracts

This document defines the strict JSON schemas required for communication across the HungryHippo microservice architecture. Any changes to these data structures must be coordinated across the Python Producer, Elixir Ingestor, and Python AI Oracle.

---

## 1. Kafka: Raw Market Ticks
**Topic:** `raw_market_ticks`
**Producer:** Python Simulation Script
**Consumer:** Elixir Ingestor (Broadway)
**Purpose:** Ingests the initial, unfiltered high-frequency price stream (including the injected 5% anomalies).

```json
{
  "feed_id": "string",     // Unique identifier for the data source (e.g., "Publisher_3-FOO/BAR")
  "price": "float",        // The raw market price
  "timestamp": "integer"   // Epoch time in milliseconds
}