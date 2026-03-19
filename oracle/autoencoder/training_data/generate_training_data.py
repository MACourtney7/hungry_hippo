import csv
import random
import time

# --- Configuration ---
NUM_TICKS = 50000
START_PRICE = 65000.0
VOLATILITY = 0.0001  # Matches your Producer's percentage multiplier
OUTPUT_FILE = "training_data.csv"

def generate_data():
    print(f"Generating {NUM_TICKS} clean ticks using Production math...")

    current_time_ms = int(time.time() * 1000)
    current_price = START_PRICE

    with open(OUTPUT_FILE, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(["timestamp", "feed_id", "ticker", "publisher", "price"])

        for i in range(NUM_TICKS):
            # 1. The exact math from your main.py Producer
            movement = current_price * random.uniform(-VOLATILITY, VOLATILITY)
            current_price += movement

            # 2. Increment timestamp by 100ms
            current_time_ms += 100

            # 3. Write to CSV
            writer.writerow([
                current_time_ms,
                "Publisher_1-FOO/BAR",
                "FOO/BAR",
                "Publisher_1",
                round(current_price, 2)
            ])

    print(f"✅ Successfully saved {NUM_TICKS} rows to {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_data()