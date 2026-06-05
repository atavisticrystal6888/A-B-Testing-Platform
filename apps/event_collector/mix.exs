defmodule EventCollector.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_collector,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {EventCollector.Application, []}
    ]
  end

  defp deps do
    [
      {:broadway, "~> 1.0"},
      # NOTE: broadway_kafka and brod require snappyer which needs the `pc` rebar3 plugin.
      # On environments with TLS interception, rebar3 cannot download `pc`.
      # Uncomment these when building in Docker or resolving TLS cert issues:
      # {:broadway_kafka, "~> 0.4"},
      # {:brod, "~> 3.18"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:experiment_hub, in_umbrella: true},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: [:test, :dev]}
    ]
  end
end
