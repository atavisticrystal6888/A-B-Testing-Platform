defmodule ExperimentHub.Exports.CsvExporter do
  @moduledoc """
  CSV export for experiment results (FR-120).
  """

  @doc """
  Export experiment results as CSV string.
  """
  def export(experiment, results, _opts \\ []) do
    headers = [
      "variant_key",
      "variant_name",
      "sample_size",
      "conversions",
      "conversion_rate",
      "ci_lower",
      "ci_upper",
      "p_value"
    ]

    rows =
      Enum.map(results, fn result ->
        [
          result[:variant_key] || "",
          result[:variant_name] || "",
          to_string(result[:sample_size] || 0),
          to_string(result[:conversions] || 0),
          to_string(result[:conversion_rate] || 0.0),
          to_string(result[:ci_lower] || ""),
          to_string(result[:ci_upper] || ""),
          to_string(result[:p_value] || "")
        ]
      end)

    csv =
      [headers | rows]
      |> Enum.map(&Enum.join(&1, ","))
      |> Enum.join("\n")

    {:ok,
     "# Experiment: #{experiment.name}\n# Key: #{experiment.key}\n# Exported: #{DateTime.utc_now() |> DateTime.to_iso8601()}\n\n#{csv}"}
  end
end
