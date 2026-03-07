from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import numpy as np

app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "ok"}

class PriceWindow(BaseModel):
    feed_id: str
    prices: List[float]

@app.post("/reconstruct")
async def reconstruct(data: PriceWindow):
    # In a production scenario, you would load a PyTorch .pth model here.
    # For now, we implement a 'Smoothing Reconstructor' (Moving Average)
    # to simulate the Autoencoder's 'denoising' effect.

    input_series = np.array(data.prices)

    # Simulate LSTM reconstruction: it ignores the 'spike' at the end
    # and projects the trend of the previous 9 points.
    predicted_price = np.mean(input_series[:-1])

    # Calculate Divergence Delta
    original_anomaly = input_series[-1]
    delta = abs(original_anomaly - predicted_price)

    return {
        "corrected_price": float(predicted_price),
        "divergence_delta": float(delta),
        "status": "corrected"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=5001)
