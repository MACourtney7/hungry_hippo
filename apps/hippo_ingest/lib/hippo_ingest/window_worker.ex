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
    {:ok, %{feed_id: feed_id, welford: Native.init_state()}}
  end

  @impl true
  def handle_cast({:process_tick, price}, %{welford: old_state} = state) do
    # Call the Rust NIF
    {new_welford, z_score} = Native.update_and_get_z_score(old_state, price)

    # Threshold for anomaly detection: Z-score > 3.0 is statistically significant
    if z_score > 3.0 and old_state.count > 5 do
      Logger.error("!!! ANOMALY DETECTED on #{state.feed_id} !!! Z-Score: #{Float.round(z_score, 2)} | Price: #{price}")
    end

    {:noreply, %{state | welford: new_welford}}
  end
end
