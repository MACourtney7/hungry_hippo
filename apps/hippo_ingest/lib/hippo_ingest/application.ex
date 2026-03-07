defmodule HippoIngest.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # 1. Registry to look up WindowWorkers by feed_id
      {Registry, keys: :unique, name: HippoIngest.FeedRegistry},

      # 2. DynamicSupervisor to spawn isolated WindowWorkers on demand
      {DynamicSupervisor, strategy: :one_for_one, name: HippoIngest.WorkerSupervisor},

      # 3. The Broadway Kafka Pipeline consumer
      HippoIngest.Pipeline
    ]

    opts = [strategy: :one_for_one, name: HippoIngest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
