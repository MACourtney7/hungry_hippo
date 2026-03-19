import pandas as pd
import numpy as np
import torch
import torch.nn as nn
from sklearn.preprocessing import MinMaxScaler
from torch.utils.data import DataLoader, TensorDataset

# --- 1. Configuration ---
FILE_PATH = "training_data.csv"
SEQ_LENGTH = 50  # How many ticks the model looks at at once
BATCH_SIZE = 64
EPOCHS = 20
LEARNING_RATE = 0.001

# --- 2. Data Preparation ---
print("Loading and scaling data...")
df = pd.read_csv(FILE_PATH)
prices = df[['price']].values

# Neural networks like data scaled between 0 and 1
scaler = MinMaxScaler()
prices_scaled = scaler.fit_transform(prices)

# Create sliding windows (e.g., ticks 0-50, then 1-51, then 2-52)
def create_sequences(data, seq_length):
    xs = []
    for i in range(len(data) - seq_length):
        xs.append(data[i:(i + seq_length)])
    return np.array(xs)

X = create_sequences(prices_scaled, SEQ_LENGTH)
X_tensor = torch.tensor(X, dtype=torch.float32)

# We want the model to output exactly what we input (Autoencoder)
dataset = TensorDataset(X_tensor, X_tensor)
dataloader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)

# --- 3. Model Architecture ---
class LSTMAutoencoder(nn.Module):
    def __init__(self, seq_len, n_features, embedding_dim=16):
        super(LSTMAutoencoder, self).__init__()
        self.seq_len = seq_len
        self.n_features = n_features
        self.embedding_dim = embedding_dim

        # Encoder: Compress 50 ticks down to 16 numbers
        self.encoder_lstm = nn.LSTM(n_features, embedding_dim, batch_first=True)

        # Decoder: Expand those 16 numbers back to 50 ticks
        self.decoder_lstm = nn.LSTM(embedding_dim, n_features, batch_first=True)

    def forward(self, x):
        # Encode
        _, (hidden, _) = self.encoder_lstm(x)

        # Hidden state shape: (1, batch_size, embedding_dim). Reshape to match batch_first
        hidden = hidden.transpose(0, 1)

        # Repeat the hidden state for the sequence length
        hidden_repeated = hidden.repeat(1, self.seq_len, 1)

        # Decode
        decoded, _ = self.decoder_lstm(hidden_repeated)
        return decoded

# --- 4. Training Loop ---
# Use Apple Silicon (MPS) if available, otherwise CPU
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
print(f"Using device: {device}")

model = LSTMAutoencoder(seq_len=SEQ_LENGTH, n_features=1).to(device)
optimizer = torch.optim.Adam(model.parameters(), lr=LEARNING_RATE)
criterion = nn.MSELoss()

print("Starting training...")
for epoch in range(EPOCHS):
    model.train()
    train_loss = 0

    for batch_x, batch_y in dataloader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)

        optimizer.zero_grad()
        output = model(batch_x)
        loss = criterion(output, batch_y)

        loss.backward()
        optimizer.step()
        train_loss += loss.item()

    avg_loss = train_loss / len(dataloader)
    if (epoch + 1) % 5 == 0 or epoch == 0:
        print(f"Epoch [{epoch+1}/{EPOCHS}], Loss: {avg_loss:.6f}")

# --- 5. Save the Model ---
torch.save(model.state_dict(), "autoencoder_model.pth")
print("✅ Training complete. Model saved as 'autoencoder_model.pth'.")