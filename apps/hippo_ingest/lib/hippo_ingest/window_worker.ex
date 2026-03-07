defmodule HippoIngest.WindowWorker do
  use GenServer
  require Logger

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
    Logger.info("Starting WindowWorker for feed: #{feed_id}")
    # State is initialized as an empty list
    {:ok, []}
  end

  @impl true
  def handle_cast({:process_tick, price}, state) do
    # Prepend new price, take only the first 10 elements to maintain the sliding window
    new_window = [price | state] |> Enum.take(10)

    # Debug log to verify the window is updating
    Logger.debug("Window for #{inspect(self())}: #{inspect(new_window)}")

    {:noreply, new_window}
  end
end
