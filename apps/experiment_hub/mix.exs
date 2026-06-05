defmodule ExperimentHub.MixProject do
  use Mix.Project

  def project do
    [
      app: :experiment_hub,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ExperimentHub.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:oban, "~> 2.17"},
      {:nimble_options, "~> 1.1"},
      {:pbkdf2_elixir, "~> 2.2"},
      {:redix, "~> 1.4"},
      {:req, "~> 0.5"},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: [:test, :dev]},
      {:ex_machina, "~> 2.7", only: :test}
    ]
  end
end
