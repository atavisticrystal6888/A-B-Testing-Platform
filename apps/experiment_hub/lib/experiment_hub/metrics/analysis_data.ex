defmodule ExperimentHub.Metrics.AnalysisData do
  @moduledoc """
  Aggregates the real per-variant counts an analysis run needs, so the
  statistical engine computes from actual assignments/events instead of
  placeholder numbers.

  Semantics:
  - `sample_size` — distinct users assigned to the variant (denominator).
  - `conversions` — distinct *assigned* users with at least one matching
    event, attributed to their assigned variant (events are joined through
    assignments, so an event from a user who was never assigned cannot
    inflate a numerator past its denominator). A user converting twice
    counts once.
  - `sum_value` / `sum_squared_value` — totals over those users' matching
    events (bot and post-conclusion events excluded), so the engine can
    derive mean/variance over the assigned population for continuous
    (sum-type) metrics.
  """

  import Ecto.Query

  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Events.ExperimentEvent
  alias ExperimentHub.Repo

  @doc """
  Returns one stats map per variant (in sort order) for the given
  experiment metric: `%{"variant_key" => ..., "sample_size" => ...,
  "conversions" => ..., "sum_value" => ..., "sum_squared_value" => ...}`.
  Variants come from `experiment.variants`, which must be preloaded.
  """
  def variant_stats(experiment, experiment_metric) do
    event_name = experiment_metric.metric_definition.definition["event_name"]
    sample_sizes = assignment_counts(experiment.id)
    event_aggregates = event_aggregates(experiment.id, event_name)

    experiment.variants
    |> Enum.sort_by(& &1.sort_order)
    |> Enum.map(fn variant ->
      aggregate = Map.get(event_aggregates, variant.id, %{})

      %{
        "variant_key" => variant.key,
        "sample_size" => Map.get(sample_sizes, variant.id, 0),
        "conversions" => Map.get(aggregate, :conversions, 0),
        "sum_value" => Map.get(aggregate, :sum_value, 0.0),
        "sum_squared_value" => Map.get(aggregate, :sum_squared_value, 0.0)
      }
    end)
  end

  defp assignment_counts(experiment_id) do
    from(a in Assignment,
      where: a.experiment_id == ^experiment_id,
      group_by: a.variant_id,
      select: {a.variant_id, count(a.user_id, :distinct)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp event_aggregates(_experiment_id, nil), do: %{}

  defp event_aggregates(experiment_id, event_name) do
    # Attribute by the ASSIGNMENT's variant (join through assignments), not
    # the event's variant_id: keeps numerators and denominators drawn from
    # the same population, and drops events from users who were never
    # actually assigned.
    from(e in ExperimentEvent,
      join: a in Assignment,
      on:
        a.experiment_id == e.experiment_id and a.user_id == e.user_id and
          a.tenant_id == e.tenant_id,
      where:
        e.experiment_id == ^experiment_id and e.event_name == ^event_name and
          e.is_bot == false and e.is_post_conclusion == false,
      group_by: a.variant_id,
      select:
        {a.variant_id,
         %{
           conversions: count(e.user_id, :distinct),
           sum_value: coalesce(sum(e.value), 0),
           sum_squared_value: coalesce(sum(e.value * e.value), 0)
         }}
    )
    |> Repo.all()
    |> Map.new(fn {variant_id, aggregate} ->
      {variant_id,
       %{
         aggregate
         | sum_value: to_float(aggregate.sum_value),
           sum_squared_value: to_float(aggregate.sum_squared_value)
       }}
    end)
  end

  defp to_float(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp to_float(number) when is_number(number), do: number * 1.0
  defp to_float(nil), do: 0.0
end
