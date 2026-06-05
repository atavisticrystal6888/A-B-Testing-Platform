defmodule ExperimentHub.FeatureFlags.Rollout do
  @moduledoc """
  Gradual rollout management for feature flags (FR-130).
  Supports incremental rollout schedules.
  """

  alias ExperimentHub.{Repo, FeatureFlags}
  alias ExperimentHub.FeatureFlags.Flag

  @doc """
  Schedule a gradual rollout for a feature flag.
  Steps is a list of %{percentage: integer, scheduled_at: DateTime}.
  """
  def schedule_rollout(flag_id, steps) do
    flag = FeatureFlags.get_flag!(flag_id)

    metadata =
      Map.merge(flag.metadata || %{}, %{
        "rollout_schedule" =>
          Enum.map(steps, fn step ->
            %{
              "percentage" => step.percentage,
              "scheduled_at" => DateTime.to_iso8601(step.scheduled_at),
              "applied" => false
            }
          end),
        "rollout_type" => "gradual"
      })

    FeatureFlags.update_flag(flag, %{metadata: metadata})
  end

  @doc """
  Apply pending rollout steps.
  Called by Oban scheduler.
  """
  def apply_pending_steps do
    now = DateTime.utc_now()

    import Ecto.Query

    from(f in Flag,
      where: f.status == "enabled",
      where: fragment("?->>'rollout_type' = 'gradual'", f.metadata)
    )
    |> Repo.all()
    |> Enum.each(fn flag ->
      apply_flag_steps(flag, now)
    end)
  end

  defp apply_flag_steps(flag, now) do
    schedule = get_in(flag.metadata, ["rollout_schedule"]) || []

    {updated_schedule, new_percentage} =
      Enum.reduce(schedule, {[], flag.rollout_percentage}, fn step, {acc, pct} ->
        scheduled_at = parse_datetime(step["scheduled_at"])

        if !step["applied"] && scheduled_at && DateTime.compare(scheduled_at, now) != :gt do
          {acc ++ [Map.put(step, "applied", true)], step["percentage"]}
        else
          {acc ++ [step], pct}
        end
      end)

    if new_percentage != flag.rollout_percentage do
      metadata = Map.put(flag.metadata, "rollout_schedule", updated_schedule)

      FeatureFlags.update_flag(flag, %{
        rollout_percentage: new_percentage,
        metadata: metadata
      })
    end
  end

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
