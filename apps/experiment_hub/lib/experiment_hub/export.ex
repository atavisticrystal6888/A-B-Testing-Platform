defmodule ExperimentHub.Export do
  @moduledoc """
  Data export service for experiment data (FR-120).
  Supports CSV and JSON export formats.
  """

  alias ExperimentHub.{Repo, Experiments}
  alias ExperimentHub.Metrics.{ExperimentResultDaily, StatisticalAnalysis}
  alias ExperimentHub.Assignments.Assignment
  import Ecto.Query

  @doc """
  Export experiment data in specified format.
  """
  def export_experiment(experiment_id, format \\ "json", _opts \\ []) do
    case format do
      format when format in ["json", "csv"] ->
        experiment = Experiments.get_experiment!(experiment_id) |> Repo.preload(:variants)

        data = %{
          experiment: format_experiment(experiment),
          variants: Enum.map(experiment.variants, &format_variant/1),
          results: get_results(experiment_id),
          assignments_summary: get_assignment_summary(experiment_id, experiment.tenant_id),
          exported_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        case format do
          "json" -> {:ok, Jason.encode!(data, pretty: true)}
          "csv" -> {:ok, to_csv(data)}
        end

      _ ->
        {:error, :unsupported_format}
    end
  end

  @doc """
  Export daily results for an experiment.
  """
  def export_daily_results(experiment_id, format \\ "csv") do
    results =
      from(r in ExperimentResultDaily,
        where: r.experiment_id == ^experiment_id,
        order_by: [asc: r.date, asc: r.variant_id]
      )
      |> Repo.all()

    rows =
      Enum.map(results, fn r ->
        %{
          date: r.date,
          variant_id: r.variant_id,
          unique_users: r.unique_users,
          conversions: r.conversions,
          conversion_value_sum: r.conversion_value_sum,
          metric_name: r.metric_name
        }
      end)

    case format do
      "csv" -> {:ok, rows_to_csv(rows)}
      "json" -> {:ok, Jason.encode!(rows, pretty: true)}
      _ -> {:error, :unsupported_format}
    end
  end

  defp format_experiment(exp) do
    %{
      id: exp.id,
      name: exp.name,
      key: exp.key,
      status: exp.status,
      hypothesis: exp.hypothesis,
      started_at: exp.started_at,
      ended_at: exp.ended_at
    }
  end

  defp format_variant(v) do
    %{
      id: v.id,
      name: v.name,
      key: v.key,
      is_control: v.is_control,
      traffic_allocation: v.traffic_allocation
    }
  end

  defp get_results(experiment_id) do
    from(sa in StatisticalAnalysis,
      where: sa.experiment_id == ^experiment_id,
      order_by: [desc: sa.inserted_at],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> nil
      analysis -> analysis.results
    end
  end

  defp get_assignment_summary(experiment_id, tenant_id) do
    from(a in Assignment,
      where: a.experiment_id == ^experiment_id and a.tenant_id == ^tenant_id,
      group_by: a.variant_id,
      select: %{variant_id: a.variant_id, count: count(a.id)}
    )
    |> Repo.all()
  end

  defp to_csv(data) do
    header = "variant_name,variant_key,is_control,traffic_allocation\r\n"

    rows =
      Enum.map(data.variants, fn v ->
        "#{v.name},#{v.key},#{v.is_control},#{v.traffic_allocation}\r\n"
      end)

    header <> Enum.join(rows)
  end

  defp rows_to_csv([]), do: ""

  defp rows_to_csv([first | _] = rows) do
    headers = first |> Map.keys() |> Enum.join(",")

    data_rows =
      Enum.map(rows, fn row ->
        row |> Map.values() |> Enum.map(&to_string/1) |> Enum.join(",")
      end)

    Enum.join([headers | data_rows], "\r\n")
  end
end
