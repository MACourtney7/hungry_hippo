defmodule HippoIngest.Pipeline do
  use Broadway
  require Logger

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayKafka.Producer, [
          hosts: [{"kafka", 9092}],
          group_id: "hippo_ingest_group",
          topics: ["raw_market_ticks"]
        ]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 10]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: data} = message, _) do
    case Jason.decode(data) do
      {:ok, %{"feed_id" => feed_id, "price" => price}} ->
        ensure_worker_running(feed_id)
        HippoIngest.WindowWorker.process_tick(feed_id, price)
        message

      {:error, _reason} ->
        Logger.error("Failed to decode Kafka message: #{inspect(data)}")
        Message.failed(message, "invalid-json")
    end
  end

  defp ensure_worker_running(feed_id) do
    case DynamicSupervisor.start_child(HippoIngest.WorkerSupervisor, {HippoIngest.WindowWorker, feed_id}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> Logger.error("Failed to start worker for #{feed_id}: #{inspect(error)}")
    end
  end
end
