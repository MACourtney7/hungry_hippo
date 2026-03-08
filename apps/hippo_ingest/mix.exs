defmodule HippoIngest.MixProject do
  use Mix.Project

  def project do
    [
      app: :hippo_ingest,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {HippoIngest.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:broadway_kafka, "~> 0.4.1"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.0"},
      {:hippo_native, in_umbrella: true},
      {:telemetry_metrics_prometheus, "~> 1.1"},
      {:telemetry_poller, "~> 1.3"}
    ]
  end
end
