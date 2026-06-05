defmodule ExperimentHub.Assignments.ExperimentCache do
  @moduledoc """
  Redis-backed cache for experiment configuration used during assignment.
  Caches experiment + variants with 5-minute TTL.
  Invalidation on config change.
  """

  @ttl_seconds 300

  @doc """
  Get cached experiment config or fetch from DB.
  Returns `{:ok, experiment}` with preloaded variants or `{:error, reason}`.
  """
  def get_or_fetch(tenant_id, experiment_key) do
    cache_key = cache_key(tenant_id, experiment_key)

    case redis_get(cache_key) do
      {:ok, nil} ->
        fetch_and_cache(tenant_id, experiment_key, cache_key)

      {:ok, data} ->
        {:ok, deserialize(data)}

      {:error, _reason} ->
        # Redis down, fall through to DB
        fetch_from_db(tenant_id, experiment_key)
    end
  end

  @doc """
  Invalidate cached experiment config when configuration changes.
  """
  def invalidate(tenant_id, experiment_key) do
    cache_key = cache_key(tenant_id, experiment_key)
    redis_del(cache_key)
  end

  defp fetch_and_cache(tenant_id, experiment_key, cache_key) do
    case fetch_from_db(tenant_id, experiment_key) do
      {:ok, experiment} ->
        data = serialize(experiment)
        redis_setex(cache_key, @ttl_seconds, data)
        {:ok, experiment}

      error ->
        error
    end
  end

  defp fetch_from_db(tenant_id, experiment_key) do
    import Ecto.Query

    query =
      from(e in ExperimentHub.Experiments.Experiment,
        where: e.tenant_id == ^tenant_id and e.key == ^experiment_key,
        preload: [:variants]
      )

    case ExperimentHub.Repo.one(query) do
      nil -> {:error, :experiment_not_found}
      experiment -> {:ok, experiment}
    end
  end

  defp cache_key(tenant_id, experiment_key) do
    "exp:#{tenant_id}:#{experiment_key}"
  end

  defp serialize(experiment) do
    %{
      id: experiment.id,
      tenant_id: experiment.tenant_id,
      key: experiment.key,
      status: experiment.status,
      variants:
        Enum.map(experiment.variants, fn v ->
          %{
            id: v.id,
            key: v.key,
            name: v.name,
            is_control: v.is_control,
            traffic_allocation: v.traffic_allocation,
            sort_order: v.sort_order
          }
        end)
    }
    |> Jason.encode!()
  end

  defp deserialize(json) do
    data = Jason.decode!(json)

    %ExperimentHub.Experiments.Experiment{
      id: data["id"],
      tenant_id: data["tenant_id"],
      key: data["key"],
      status: data["status"],
      variants:
        Enum.map(data["variants"], fn v ->
          %ExperimentHub.Experiments.Variant{
            id: v["id"],
            key: v["key"],
            name: v["name"],
            is_control: v["is_control"],
            traffic_allocation: v["traffic_allocation"],
            sort_order: v["sort_order"]
          }
        end)
    }
  end

  # Redis helpers using Redix connection
  defp redis_get(key) do
    case Process.whereis(ExperimentHub.Redix) do
      nil -> {:ok, nil}
      _pid -> Redix.command(ExperimentHub.Redix, ["GET", key])
    end
  end

  defp redis_setex(key, ttl, value) do
    case Process.whereis(ExperimentHub.Redix) do
      nil -> :ok
      _pid -> Redix.command(ExperimentHub.Redix, ["SETEX", key, to_string(ttl), value])
    end
  end

  defp redis_del(key) do
    case Process.whereis(ExperimentHub.Redix) do
      nil -> :ok
      _pid -> Redix.command(ExperimentHub.Redix, ["DEL", key])
    end
  end
end
