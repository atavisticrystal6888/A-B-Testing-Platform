defmodule ExperimentHub.Metrics.Segments do
  @moduledoc """
  Descriptive per-segment result breakdowns: for one experiment metric,
  splits sample sizes and conversions by a user attribute captured at
  assignment time (`assignments.context`).

  Deliberately descriptive-only — no p-values. Per-segment significance
  testing multiplies comparisons and inflates false-positive rates, so the
  numbers here are for spotting "did this work for mobile users" patterns,
  not for shipping decisions.
  """

  import Ecto.Query

  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Events.ExperimentEvent
  alias ExperimentHub.Repo

  @attribute_format ~r/^[a-zA-Z0-9_.\-]{1,64}$/
  @max_segments 50
  @unknown "(unknown)"

  @doc """
  Returns `{:ok, breakdown}` where breakdown is a list of
  `%{segment: ..., variants: [%{variant_key, sample_size, conversions,
  conversion_rate}]}` sorted by total sample size descending, or
  `{:error, :invalid_attribute}` for malformed attribute names.

  Conversions attribute a converting user to the segment recorded on their
  assignment (not on the event), so numerators and denominators always
  come from the same population split.
  """
  def breakdown(experiment, experiment_metric, attribute) do
    if Regex.match?(@attribute_format, attribute) do
      event_name = experiment_metric.metric_definition.definition["event_name"]

      sample_sizes = assignment_counts(experiment.id, attribute)
      conversions = conversion_counts(experiment.id, attribute, event_name)

      {:ok, build_rows(experiment, sample_sizes, conversions)}
    else
      {:error, :invalid_attribute}
    end
  end

  # The segment expression must be aliased with selected_as/2 and referenced
  # via selected_as/1 in group_by — repeating the fragment in both clauses
  # makes Ecto emit distinct bind params, which Postgres rejects with
  # "column must appear in the GROUP BY clause".
  defp assignment_counts(experiment_id, attribute) do
    from(a in Assignment,
      where: a.experiment_id == ^experiment_id,
      group_by: [a.variant_id, selected_as(:segment)],
      select:
        {selected_as(fragment("COALESCE(?->>?, ?)", a.context, ^attribute, ^@unknown), :segment),
         a.variant_id, count(a.user_id, :distinct)}
    )
    |> Repo.all()
  end

  defp conversion_counts(_experiment_id, _attribute, nil), do: []

  defp conversion_counts(experiment_id, attribute, event_name) do
    from(e in ExperimentEvent,
      join: a in Assignment,
      on:
        a.experiment_id == e.experiment_id and a.user_id == e.user_id and
          a.tenant_id == e.tenant_id,
      where:
        e.experiment_id == ^experiment_id and e.event_name == ^event_name and
          e.is_bot == false and e.is_post_conclusion == false,
      group_by: [a.variant_id, selected_as(:segment)],
      select:
        {selected_as(fragment("COALESCE(?->>?, ?)", a.context, ^attribute, ^@unknown), :segment),
         a.variant_id, count(e.user_id, :distinct)}
    )
    |> Repo.all()
  end

  defp build_rows(experiment, sample_sizes, conversions) do
    conversions_map =
      Map.new(conversions, fn {segment, variant_id, count} -> {{segment, variant_id}, count} end)

    variants = Enum.sort_by(experiment.variants, & &1.sort_order)

    sample_sizes
    |> Enum.group_by(fn {segment, _variant_id, _count} -> segment end)
    |> Enum.map(fn {segment, rows} ->
      by_variant = Map.new(rows, fn {_segment, variant_id, count} -> {variant_id, count} end)

      variant_rows =
        Enum.map(variants, fn variant ->
          sample_size = Map.get(by_variant, variant.id, 0)
          converted = Map.get(conversions_map, {segment, variant.id}, 0)

          %{
            variant_key: variant.key,
            sample_size: sample_size,
            conversions: converted,
            conversion_rate: if(sample_size > 0, do: converted / sample_size)
          }
        end)

      %{
        segment: segment,
        total_sample_size: Enum.sum(Enum.map(variant_rows, & &1.sample_size)),
        variants: variant_rows
      }
    end)
    |> Enum.sort_by(& &1.total_sample_size, :desc)
    |> Enum.take(@max_segments)
  end
end
