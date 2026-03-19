defmodule HippoIngest.Application do
  use Application
  import Telemetry.Metrics
  require Logger

  @kafka_hosts [{"kafka", 9092}]
  @topics ["raw_market_ticks", "clean_market_ticks"]

  @impl true
  def start(_type, _args) do
    # It can take a moment for the Kafka container to be ready, even after the
    # healthcheck passes. This function will block until the topics are created.
    create_kafka_topics()

    children = [
      # Start the Prometheus Exporter process
      {TelemetryMetricsPrometheus, [metrics: metrics(), port: 4000, host: {0, 0, 0, 0}]},

      # Registry to look up WindowWorkers by feed_id
      {Registry, [keys: :unique, name: HippoIngest.FeedRegistry]},

      # DynamicSupervisor to spawn isolated WindowWorkers on demand
      {DynamicSupervisor, [strategy: :one_for_one, name: HippoIngest.WorkerSupervisor]},

      # Erlang brod_client
      %{
        id: :kafka_egress_client,
        start: {:brod_client, :start_link, [@kafka_hosts, :kafka_client, []]},
        type: :worker,
        restart: :permanent,
        shutdown: 5000
      },

      # The Broadway Kafka Pipeline consumer
      {HippoIngest.Pipeline, []}
    ]

    opts = [strategy: :one_for_one, name: HippoIngest.Supervisor]
    # Start the supervisor
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Manually start the producer once the client is definitely up
        _ = :brod.start_producer(:kafka_client, "clean_market_ticks", [])
        {:ok, pid}

      error ->
        error
    end
  end

  defp metrics do
    [
      # Counter for total ticks
      counter("hippo_ingest.ticks.total",
        event_name: [:hippo_ingest, :ticks, :total],
        tags: [:feed_id, :is_corrected]
      ),

      # Gauge for tick price
      last_value("hippo_ingest.tick.price",
        event_name: [:hippo_ingest, :tick, :price],
        measurement: :price,
        tags: [:feed_id, :type]
      ),

      # Tracks the cumulative value of all price corrections
      last_value("hippo_ingest.tick.delta.total",
        event_name: [:hippo_ingest, :tick, :delta],
        measurement: :value,
        tags: [:feed_id]
      )
    ]
  end

  # This function blocks, but handles topics sequentially to ensure clean pattern matching.
  defp create_kafka_topics() do
    Enum.each(@topics, fn topic ->
      topic_config = %{
        name: topic,
        num_partitions: 1,
        replication_factor: 1,
        configs: [],
        assignments: []
      }
      ensure_topic_created(topic_config, 10)
    end)
  end

  defp ensure_topic_created(config, 0) do
    raise "Failed to create Kafka topic '#{config.name}' after multiple retries."
  end

  defp ensure_topic_created(config, retries) do
    case :brod.create_topics(@kafka_hosts, [config], %{timeout: 5000}) do
      :ok ->
        Logger.info("Kafka topic '#{config.name}' created successfully.")
        :ok

      # Catch the tuple format (some Kafka versions return this)
      {:error, {:topic_already_exists, _}} ->
        Logger.info("Kafka topic '#{config.name}' already exists.")
        :ok

      # Catch the raw string format your Kafka broker is actually returning
      {:error, reason} when is_binary(reason) ->
        if String.contains?(reason, "already exists") do
          Logger.info("Kafka topic '#{config.name}' already exists.")
          :ok
        else
          retry_creation(config, reason, retries)
        end

      # Catch any other unexpected error formats
      {:error, reason} ->
        retry_creation(config, reason, retries)
    end
  end

  defp retry_creation(config, reason, retries) do
    Logger.warning("Failed to create '#{config.name}': #{inspect(reason)}. Retrying in 1s...")
    Process.sleep(1000)
    ensure_topic_created(config, retries - 1)
  end
end
