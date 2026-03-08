defmodule HippoIngest.Application do
  use Application
  import Telemetry.Metrics

  @impl true
  def start(_type, _args) do
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
        start: {:brod_client, :start_link, [[{"kafka", 9092}], :kafka_client, []]},
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

      error -> error
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
end
