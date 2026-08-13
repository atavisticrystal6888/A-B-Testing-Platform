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
      # broadway_kafka -> brod -> kafka_protocol -> crc32cer (C NIF).
      # crc32cer's hex package only builds its NIF on unix (make pre-hook);
      # on Windows compile libcrc32cer_nif.dll manually with gcc from
      # deps/crc32cer/{c_src,external/crc32c} into deps/crc32cer/priv/.
      {:broadway_kafka, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:experiment_hub, in_umbrella: true},
      {:mox, "~> 1.1", only: :test},
      {:stream_data, "~> 1.1", only: [:test, :dev]}
    ]
  end
end
