# HungryHippo

High-throughput market data anomaly corrector built in Elixir/Rustler and PyTorch.

This project uses a combination of Elixir for high-concurrency data ingestion, Rust for high-performance statistical analysis, and Python for machine learning-based data correction.

## Development Environment

This project is fully containerized using Docker. All services are defined in `docker-compose.yml` and can be built and run with Docker Compose.

## Setup

1.  **Build the services**:
    ```bash
    docker-compose build
    ```

2.  **Start the services**:
    ```bash
    docker-compose up
    ```

The application will now be running. Source code is mounted into the containers, so local changes will be reflected automatically.
