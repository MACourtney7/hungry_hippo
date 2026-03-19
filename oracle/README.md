# Hippo Oracle (Python / PyTorch / FastAPI)

The Oracle is the probabilistic AI corrector of the HungryHippo pipeline. It is a stateless HTTP microservice that receives anomalous data windows from Elixir, mathematically reconstructs the corrupted tick, and returns the sanitized value.

## Architecture & State
* **FastAPI Server (`app.py`):** Exposes a single `POST /reconstruct` endpoint. It expects a chronologically ordered array of 50 floats (prices).
* **AI Model (`autoencoder_model.pth`):** A pre-trained Long Short-Term Memory (LSTM) Autoencoder. It was trained to understand the standard volatility of a $65,000 Bitcoin uniform distribution random walk.

## The Reconstruction Math (The "Blindfold" Technique)
When the Oracle receives the 50-tick window, the 50th tick is known to be the massive 5% anomaly. If we feed the anomaly into the model, it skews the prediction.
1. **Masking:** Before scaling the data, the Oracle overwrites the 50th tick (the anomaly) with the value of the 49th tick. This "blinds" the AI to the bad data.
2. **Scaling:** The 50-tick window is normalized using `MinMaxScaler` so it fits the `[-1, 1]` or `[0, 1]` tensor boundaries expected by PyTorch.
3. **Prediction:** The tensor is passed through the LSTM. The AI predicts what the 50th tick *should* have been based on the trajectory of the previous 49.
4. **Inverse Transformation:** The scaled prediction is converted back into a real-world USD price and returned to Elixir along with the divergence delta.