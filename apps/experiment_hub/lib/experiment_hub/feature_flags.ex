defmodule ExperimentHub.FeatureFlags do
  @moduledoc """
  Feature flag management context (FR-125).
  Simple boolean or percentage-based feature flags.
  """

  alias ExperimentHub.{Repo}
  alias ExperimentHub.FeatureFlags.Flag
  import Ecto.Query

  @doc """
  List all flags for a tenant.
  """
  def list_flags(tenant_id, opts \\ []) do
    status = opts[:status]

    query = from(f in Flag, where: f.tenant_id == ^tenant_id, order_by: [asc: f.key])

    query = if status, do: where(query, [f], f.status == ^status), else: query

    Repo.all(query)
  end

  @doc """
  Get a single flag by ID.
  """
  def get_flag!(id), do: Repo.get!(Flag, id)

  @doc """
  Get a flag by key for a tenant.
  """
  def get_flag_by_key(tenant_id, key) do
    Repo.get_by(Flag, tenant_id: tenant_id, key: key)
  end

  @doc """
  Create a new feature flag.
  """
  def create_flag(attrs) do
    %Flag{}
    |> Flag.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a feature flag.
  """
  def update_flag(flag, attrs) do
    flag
    |> Flag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a feature flag.
  """
  def delete_flag(flag), do: Repo.delete(flag)

  @doc """
  Evaluate a flag for a given user context.
  Returns {:ok, boolean} or {:error, :not_found}.
  """
  def evaluate(tenant_id, flag_key, context \\ %{}) do
    case get_flag_by_key(tenant_id, flag_key) do
      nil -> {:error, :not_found}
      flag -> {:ok, evaluate_flag(flag, context)}
    end
  end

  @doc """
  Bulk evaluate multiple flags for a user.
  """
  def evaluate_all(tenant_id, flag_keys, context \\ %{}) do
    flags =
      from(f in Flag,
        where: f.tenant_id == ^tenant_id and f.key in ^flag_keys
      )
      |> Repo.all()

    Map.new(flags, fn flag ->
      {flag.key, evaluate_flag(flag, context)}
    end)
  end

  defp evaluate_flag(%Flag{status: "disabled"}, _context), do: false
  defp evaluate_flag(%Flag{status: "enabled", rollout_percentage: 10_000}, _context), do: true

  defp evaluate_flag(%Flag{status: "enabled"} = flag, context) do
    user_id = Map.get(context, "user_id") || Map.get(context, :user_id, "")
    hash = :erlang.phash2({flag.key, user_id}, 10_000)
    hash < flag.rollout_percentage
  end

  defp evaluate_flag(_, _), do: false
end
