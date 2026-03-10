from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import numpy as np
import torch
import torch.nn as nn
import os

app = FastAPI()

# --- 1. Define the Model Architecture (Must match training exactly) ---
class LSTMAutoencoder(nn.Module):
    def __init__(self, seq_len, n_features, embedding_dim=16):
        super(LSTMAutoencoder, self).__init__()
        self.seq_len = seq_len
        self.encoder_lstm = nn.LSTM(n_features, embedding_dim, batch_first=True)
        self.decoder_lstm = nn.LSTM(embedding_dim, n_features, batch_first=True)

    def forward(self, x):
        _, (hidden, _) = self.encoder_lstm(x)
        hidden = hidden.transpose(0, 1)
        hidden_repeated = hidden.repeat(1, self.seq_len, 1)
        decoded, _ = self.decoder_lstm(hidden_repeated)
        return decoded

# --- 2. Load the Pre-Trained Brain on Startup ---
# Use CPU for inference to keep the Docker container lightweight
device = torch.device("cpu")
SEQ_LENGTH = 50

model = LSTMAutoencoder(seq_len=SEQ_LENGTH, n_features=1).to(device)

MODEL_PATH = "autoencoder_model.pth"
if os.path.exists(MODEL_PATH):
    # map_location ensures it loads on CPU even if trained on Mac MPS
    model.load_state_dict(torch.load(MODEL_PATH, map_location=device))
    model.eval() # Set model to inference mode
    print("✅ PyTorch Autoencoder loaded successfully.")
else:
    print(f"⚠️ WARNING: {MODEL_PATH} not found. The endpoint will fail.")

# --- 3. FastAPI Endpoints ---
@app.get("/health")
async def health():
    return {"status": "ok", "model_loaded": os.path.exists(MODEL_PATH)}

class PriceWindow(BaseModel):
    feed_id: str
    prices: List[float]

@app.post("/reconstruct")
async def reconstruct(data: PriceWindow):
    input_series = np.array(data.prices)

    # 1. Enforce Sequence Length (Pad or truncate to exactly 50 ticks)
    if len(input_series) < SEQ_LENGTH:
        pad_width = SEQ_LENGTH - len(input_series)
        input_series = np.pad(input_series, (pad_width, 0), mode='edge')
    elif len(input_series) > SEQ_LENGTH:
        input_series = input_series[-SEQ_LENGTH:]

    # 2. Scale the data (Scale based on normal ticks, ignoring the anomaly spike at the end)
    normal_data = input_series[:-1]
    min_val = np.min(normal_data)
    max_val = np.max(normal_data)
    if max_val == min_val:
        max_val += 1e-6 # Prevent division by zero if all prices are identical

    scaled_series = (input_series - min_val) / (max_val - min_val)

    # 3. Prepare Tensor: Shape needs to be (batch_size=1, sequence_length=50, features=1)
    x_tensor = torch.tensor(scaled_series, dtype=torch.float32).unsqueeze(0).unsqueeze(-1).to(device)

    # 4. Predict (Forward Pass)
    with torch.no_grad():
        reconstructed = model(x_tensor)

    # 5. Extract the predicted value for the LAST tick (where the anomaly is)
    scaled_pred = reconstructed[0, -1, 0].item()

    # 6. Inverse Scale back to Real Dollars
    predicted_price = (scaled_pred * (max_val - min_val)) + min_val

    # 7. Calculate Divergence Delta
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