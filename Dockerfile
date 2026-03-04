# --- Build Stage ---
FROM hexpm/elixir:1.19.5-erlang-28.1-debian-bookworm-20260202-slim AS builder

# Install build essentials and Rust
RUN apt-get update && apt-get install -y build-essential curl git
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV=prod

# Copy umbrella files
COPY . .

RUN mix deps.get
RUN mix compile

# --- Run Stage ---
FROM hexpm/elixir:1.19.5-erlang-28.1-debian-bookworm-20260202-slim

RUN apt-get update && apt-get install -y libssl-dev ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled artifacts from the builder
COPY --from=builder /app /app

# Set environment to prod
ENV MIX_ENV=prod

# Now iex will be available
CMD ["iex", "-S", "mix"]