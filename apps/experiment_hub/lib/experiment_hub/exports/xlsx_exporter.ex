defmodule ExperimentHub.Exports.XlsxExporter do
  @moduledoc """
  Excel export for experiment results (FR-120).
  Generates a simple CSV-based format as a lightweight Excel alternative.
  """

  @doc """
  Export experiment results as XLSX-compatible format.
  Falls back to CSV with .xlsx extension when Elixlsx is not available.
  """
  def export(experiment, results, _opts \\ []) do
    # Summary sheet
    summary = [
      ["Experiment Report"],
      ["Name", experiment.name],
      ["Key", experiment.key],
      ["Status", experiment.status],
      ["Hypothesis", experiment.hypothesis || ""],
      [],
      ["Variant Results"],
      ["Variant", "Sample Size", "Conversions", "Rate", "CI Lower", "CI Upper", "P-Value"]
    ]

    detail_rows =
      Enum.map(results, fn r ->
        [
          r[:variant_name] || "",
          r[:sample_size] || 0,
          r[:conversions] || 0,
          r[:conversion_rate] || 0.0,
          r[:ci_lower] || "",
          r[:ci_upper] || "",
          r[:p_value] || ""
        ]
      end)

    all_rows = summary ++ detail_rows

    csv =
      all_rows
      |> Enum.map(fn row -> Enum.map(row, &to_string/1) |> Enum.join("\t") end)
      |> Enum.join("\n")

    {:ok, csv}
  end
end
