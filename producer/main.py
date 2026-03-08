import os
import json
import time
import random
import sys
from confluent_kafka import Producer

# Configuration via Environment Variables
KAFKA_BROKER = os.environ.get("KAFKA_BROKER", "kafka:9092")
TOPIC = os.environ.get("TARGET_TOPIC", "raw_market_ticks")
NUM_PUBLISHERS = int(os.environ.get("NUM_PUBLISHERS", "3"))
TICKER = os.environ.get("TICKER", "FOO/BAR")
TICK_RATE = float(os.environ.get("TICK_RATE", "0.1"))
VOLATILITY = float(os.environ.get("VOLATILITY", "0.0001"))

BASE_PRICE = 65000.0

# Dynamically initialize the state for the requested quantity of producers
state = {}
for i in range(1, NUM_PUBLISHERS + 1):
    feed_id = f"Publisher_{i}-{TICKER}"
    # Give each publisher a slightly different starting price
    starting_price = BASE_PRICE + random.uniform(-5.0, 5.0)
    state[feed_id] = {"price": starting_price, "volatility": VOLATILITY}

def delivery_report(err, msg):
    if err is not None:
        print(f"Message delivery failed: {err}", file=sys.stderr)

def generate_tick(feed_id, data):
    # Standard random walk
    movement = data["price"] * random.uniform(-data["volatility"], data["volatility"])
    new_price = data["price"] + movement

    # 1% chance to inject a massive anomaly (5% price jump/drop)
    is_anomaly = random.random() < 0.01
    if is_anomaly:
        anomaly_multiplier = random.choice([1.05, 0.95])
        new_price = data["price"] * anomaly_multiplier
        print(f"!!! INJECTING ANOMALY INTO {feed_id} !!!")
    else:
        # Update baseline only if it's not an anomaly so it doesn't skew future ticks
        data["price"] = new_price

    # Extract generic publisher name and ticker
    publisher, ticker = feed_id.split("-")

    return {
        "feed_id": feed_id,
        "ticker": ticker,
        "publisher": publisher,
        "price": round(new_price, 2),
        "timestamp": int(time.time() * 1000)
    }

def main():
    print(f"Connecting to Kafka at {KAFKA_BROKER}...", flush=True)

    conf = {
        'bootstrap.servers': KAFKA_BROKER,
        'client.id': 'python-producer',
        # Hardening settings
        'socket.timeout.ms': 10000,
        'reconnect.backoff.ms': 500,
        'reconnect.backoff.max.ms': 10000,
        'queue.buffering.max.messages': 100000,
        'linger.ms': 0, # Send immediately for real-time ticks
    }

    producer = Producer(conf)

    print(f"Starting tick generation for {NUM_PUBLISHERS} publishers...", flush=True)

    try:
        while True:
            for feed_id, data in state.items():
                tick = generate_tick(feed_id, data)

                try:
                    producer.produce(
                        TOPIC,
                        key=feed_id.encode('utf-8'),
                        value=json.dumps(tick).encode('utf-8'),
                        callback=delivery_report
                    )
                except BufferError:
                    print("Local queue full, waiting for free space...", file=sys.stderr)
                    producer.poll(1)
                except Exception as e:
                    print(f"Error producing: {e}", file=sys.stderr)

            # poll(0) is non-blocking. It serves the delivery_report callbacks.
            producer.poll(0)

            # Important: Periodic flush ensures data actually leaves the buffer
            # since we are producing low-volume ticks.
            if random.random() < 0.1: # Flush roughly every 1 second
                producer.flush(0.1)

            time.sleep(TICK_RATE)

    except KeyboardInterrupt:
        print("Stopping producer...")
    finally:
        print("Finalizing stream...", flush=True)
        producer.flush(10)

if __name__ == "__main__":
    # Wait for Kafka to finish booting up
    print("Pre-flight delay...", flush=True)
    time.sleep(10)
    main()