defmodule ExperimentHub.Experiments.LaunchValidator do
  @moduledoc """
  Validates pre-conditions for launching an experiment (draft → running).
  Requires:
  - Hypothesis must be present
  - At least one primary metric must be attached
  - Variants must be valid (at least 2, exactly 1 control, sum to 10000)
  """

  import Ecto.Query
  alias ExperimentHub.Repo
  alias ExperimentHub.Metrics.ExperimentMetric
  alias ExperimentHub.Experiments.VariantValidator

  @doc """
  Validates whether an experiment is ready to launch.
  Returns `:ok` or `{:error, violations}`.
  """
  def validate(experiment) do
    experiment = Repo.preload(experiment, :variants)

    violations =
      []
      |> check_hypothesis(experiment)
      |> check_primary_metric(experiment)
      |> check_variants(experiment)

    case violations do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp check_hypothesis(violations, experiment) do
    if is_nil(experiment.hypothesis) or experiment.hypothesis == "" do
      ["hypothesis_required" | violations]
    else
      violations
    end
  end

  defp check_primary_metric(violations, experiment) do
    primary_count =
      ExperimentMetric
      |> where(experiment_id: ^experiment.id, role: "primary")
      |> Repo.aggregate(:count)

    if primary_count == 0 do
      ["primary_metric_required" | violations]
    else
      violations
    end
  end

  defp check_variants(violations, experiment) do
    case VariantValidator.validate(variant_attrs(experiment.variants)) do
      :ok -> violations
      {:error, variant_violations} -> variant_violations ++ violations
    end
  end

  defp variant_attrs(variants) do
    Enum.map(variants, fn v ->
      %{
        "is_control" => v.is_control,
        "traffic_allocation" => v.traffic_allocation
      }
    end)
  end
end
