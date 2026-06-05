defmodule ExperimentHub.Analytics do
  @moduledoc """
  Platform analytics context (FR-140).
  Provides overview stats for the dashboard.
  """

  alias ExperimentHub.Repo
  alias ExperimentHub.Experiments.Experiment
  alias ExperimentHub.FeatureFlags.Flag
  alias ExperimentHub.Assignments.Assignment
  import Ecto.Query

  @doc """
  Get platform overview statistics for a tenant.
  """
  def overview(tenant_id) do
    %{
      experiments: experiment_stats(tenant_id),
      feature_flags: flag_stats(tenant_id),
      assignments: assignment_stats(tenant_id),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp experiment_stats(tenant_id) do
    from(e in Experiment,
      where: e.tenant_id == ^tenant_id,
      group_by: e.status,
      select: {e.status, count(e.id)}
    )
    |> Repo.all()
    |> Map.new()
    |> then(fn counts ->
      %{
        total: Enum.sum(Map.values(counts)),
        draft: Map.get(counts, "draft", 0),
        running: Map.get(counts, "running", 0),
        paused: Map.get(counts, "paused", 0),
        concluded: Map.get(counts, "concluded", 0)
      }
    end)
  end

  defp flag_stats(tenant_id) do
    from(f in Flag,
      where: f.tenant_id == ^tenant_id,
      group_by: f.status,
      select: {f.status, count(f.id)}
    )
    |> Repo.all()
    |> Map.new()
    |> then(fn counts ->
      %{
        total: Enum.sum(Map.values(counts)),
        enabled: Map.get(counts, "enabled", 0),
        disabled: Map.get(counts, "disabled", 0)
      }
    end)
  end

  defp assignment_stats(tenant_id) do
    start_of_today = DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")

    total =
      from(a in Assignment, where: a.tenant_id == ^tenant_id, select: count(a.id))
      |> Repo.one()

    today =
      from(a in Assignment,
        where: a.tenant_id == ^tenant_id,
        where: a.assigned_at >= ^start_of_today,
        select: count(a.id)
      )
      |> Repo.one()

    %{total: total || 0, today: today || 0}
  end
end
