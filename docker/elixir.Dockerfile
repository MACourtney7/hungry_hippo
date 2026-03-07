# Use the official Elixir image as a base
FROM elixir:1.19.5-otp-28-alpine

ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER="gcc"

# Install Rust
RUN apk add --no-cache curl build-base cmake musl-dev gcc
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Set the working directory
WORKDIR /app
