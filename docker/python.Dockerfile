# Use the official Python image as a base
FROM python:3.14.3-slim

# Install PyTorch (CPU version)
RUN pip3 install torch torchvision torchaudio

# Set the working directory
WORKDIR /app
