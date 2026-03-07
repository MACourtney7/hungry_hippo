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
  def handle_cast({:process_tick, price}, %{welford: old_state} = state) do
    # 1. Update Statistical State (Rust NIF)
    {new_welford, z_score} = Native.update_and_get_z_score(old_state, price)

    # 2. Add to local buffer
    new_buffer = [price | Enum.take(state.buffer, 9)]

    # --- DEBUG: See every tick while we troubleshoot ---
    Logger.debug("Tick: #{price} | Z: #{Float.round(z_score, 2)} | Count: #{new_welford.count}")

    if z_score > 3.0 and new_welford.count > 10 do
      # 3. PATH B: Correct pattern match for the {price, delta} tuple
      {corrected_price, delta} = call_oracle(state.feed_id, new_buffer)

      Logger.warning("""
      🎯 ANOMALY DETECTED!
      Feed: #{state.feed_id}
      Original: #{price}
      AI Correction: #{corrected_price}
      Divergence: #{Float.round(delta, 2)}
      Z-Score: #{Float.round(z_score, 2)}
      """)

      publish_clean_tick(state.feed_id, corrected_price)
    else
      # 4. PATH A: Standard Throughput
      publish_clean_tick(state.feed_id, price)
    end

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

  defp publish_clean_tick(_feed_id, _price) do
    # Logic to send back to Kafka 'clean_market_ticks' topic
    :ok
  end
end
