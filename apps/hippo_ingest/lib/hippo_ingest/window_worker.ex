defmodule HippoIngest.WindowWorker do
  use GenServer
  require Logger
  alias HippoNative.Native

  # --- Client API ---

  def start_link(feed_id) do
    name = via_tuple(feed_id)
    GenServer.start_link(__MODULE__, feed_id, name: name)
  end

  def process_tick(feed_id, price) do
    GenServer.cast(via_tuple(feed_id), {:process_tick, price})
  end

  defp via_tuple(feed_id) do
    {:via, Registry, {HippoIngest.FeedRegistry, feed_id}}
  end

  # --- Server Callbacks ---

  @impl true
  def init(feed_id) do
    Logger.info("Starting Welford Analytics for: #{feed_id}")
    # Initialize our Rust state
    {:ok, %{
      feed_id: feed_id,
      welford: Native.init_state(),
      buffer: []
    }}
  end

  @impl true
  def handle_cast({:process_tick, raw_price}, state) do
    {new_welford, z_score} = Native.update_and_get_z_score(state.welford, raw_price)
    new_buffer = [raw_price | Enum.take(state.buffer, 9)]

    {clean_price, is_corrected, delta} =
      if z_score > 3.0 and new_welford.count > 10 do
        # PATH B: Anomaly detected - Call Oracle
        {corrected_price, delta} = call_oracle(state.feed_id, new_buffer)
        Logger.warning("CORRECTED: #{raw_price} -> #{corrected_price} (Δ: #{delta})")
        {corrected_price, true, delta}
      else
        # PATH A: Standard throughput
        {raw_price, false, 0.0}
      end

    # --- Telemetry ---
    :telemetry.execute([:hippo_ingest, :tick, :price], %{price: raw_price}, %{feed_id: state.feed_id, type: "raw"})
    :telemetry.execute([:hippo_ingest, :tick, :price], %{price: clean_price}, %{feed_id: state.feed_id, type: "clean"})
    :telemetry.execute([:hippo_ingest, :ticks, :total], %{count: 1}, %{feed_id: state.feed_id, is_corrected: is_corrected})
    if is_corrected, do: :telemetry.execute([:hippo_ingest, :tick, :delta], %{value: abs(delta)}, %{feed_id: state.feed_id})

    # --- Egress ---
    publish_clean_tick(state.feed_id, clean_price, is_corrected, delta)

    {:noreply, %{state | welford: new_welford, buffer: new_buffer}}
  end

  defp call_oracle(feed_id, window) do
    # It's helpful to reverse the window here so Python gets Chronological order
    payload = %{feed_id: feed_id, prices: Enum.reverse(window)}

    case Req.post("http://oracle:5001/reconstruct", json: payload, retry: false) do
      {:ok, %{status: 200, body: %{"corrected_price" => clean, "divergence_delta" => delta}}} ->
        # Returning a tuple lets the caller know the magnitude of the AI's correction
        {clean, delta}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Oracle returned unexpected status #{status}: #{inspect(body)}")
        {List.first(window), 0.0}

      {:error, reason} ->
        Logger.error("Oracle Connection Failed: #{inspect(reason)}")
        {List.first(window), 0.0}
    end
  end

  defp publish_clean_tick(feed_id, price, is_corrected, delta) do
    topic = "clean_market_ticks"
    client = :kafka_client

    payload =
      %{
        feed_id: feed_id,
        price: price,
        delta: delta,
        is_corrected: is_corrected,
        timestamp: System.system_time(:millisecond)
      }
      |> Jason.encode!()

    # Produce synchronously to ensure data integrity
    case :brod.produce_sync(client, topic, :random, "", payload) do
      :ok ->
        :ok
      {:error, :producer_not_found} ->
        # If not found, try to start it and retry once
        IO.puts("🔄 Producer not found for #{topic}, attempting manual start...")
        :brod.start_producer(client, topic, [])

        # Wait a tiny bit for registration
        Process.sleep(100)

        # Retry the produce
        :brod.produce_sync(client, topic, :random, "", payload)
      error ->
        IO.puts("❌ Egress Failed: #{inspect(error)}")
        error
    end
  end
end
