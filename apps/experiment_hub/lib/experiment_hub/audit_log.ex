defmodule ExperimentHub.AuditLog do
  @moduledoc """
  Audit logging for experiment lifecycle events (FR-070).
  Records all state changes with before/after state.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias ExperimentHub.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @actor_types ~w(user system api_key)

  schema "audit_logs" do
    field(:tenant_id, :binary_id)
    field(:actor_id, :binary_id)
    field(:actor_type, :string)
    field(:action, :string)
    field(:resource_type, :string)
    field(:resource_id, :binary_id)
    field(:changes, :map, default: %{})
    field(:reason, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :tenant_id,
      :actor_id,
      :actor_type,
      :action,
      :resource_type,
      :resource_id,
      :changes,
      :reason,
      :metadata
    ])
    |> validate_required([:tenant_id, :actor_type, :action, :resource_type, :resource_id])
    |> validate_inclusion(:actor_type, @actor_types)
  end

  @doc """
  Log an audit event.
  """
  def log(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Log an experiment state change with before/after state.
  """
  def log_experiment_change(experiment, action, opts \\ []) do
    actor_id = opts[:actor_id]
    actor_type = opts[:actor_type] || "system"
    reason = opts[:reason]
    changes = opts[:changes] || %{}

    log(%{
      tenant_id: experiment.tenant_id,
      actor_id: actor_id,
      actor_type: actor_type,
      action: action,
      resource_type: "experiment",
      resource_id: experiment.id,
      changes: changes,
      reason: reason,
      metadata: %{
        experiment_key: experiment.key,
        experiment_name: experiment.name,
        status: experiment.status
      }
    })
  end

  @doc """
  List audit logs for a resource.
  """
  def list_for_resource(resource_type, resource_id, opts \\ []) do
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    from(a in __MODULE__,
      where: a.resource_type == ^resource_type and a.resource_id == ^resource_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  List audit logs for a tenant.
  """
  def list_for_tenant(tenant_id, opts \\ []) do
    limit = opts[:limit] || 50
    offset = opts[:offset] || 0

    from(a in __MODULE__,
      where: a.tenant_id == ^tenant_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end
end
