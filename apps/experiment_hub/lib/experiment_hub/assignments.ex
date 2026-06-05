defmodule ExperimentHub.Assignments do
  @moduledoc """
  Assignments context: deterministic variant assignment via MurmurHash3 NIF.
  Supports single and batch assignment, overrides, persistence for flip-flop prevention.
  """

  import Ecto.Query
  alias ExperimentHub.Repo

  alias ExperimentHub.Assignments.{
    AssignmentOverride,
    AssignmentPersistence,
    ExperimentCache,
    EventPublisher
  }

  @doc """
  Assign a variant for a single user + experiment.
  Priority: override > persisted assignment > hash-based.

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  def assign(tenant_id, params) do
    user_id = params["user_id"] || params[:user_id]
    experiment_key = params["experiment_key"] || params[:experiment_key]
    attributes = params["attributes"] || params[:attributes] || %{}

    with {:ok, experiment} <- ExperimentCache.get_or_fetch(tenant_id, experiment_key) do
      if experiment.status != "running" do
        fallback_result(experiment, user_id, "experiment_not_running")
      else
        do_assign(tenant_id, experiment, user_id, attributes)
      end
    end
  end

  @doc """
  Batch assignment for a single user across multiple experiments.
  Max 50 experiment keys per request.
  """
  def batch_assign(tenant_id, params) do
    user_id = params["user_id"] || params[:user_id]
    experiment_keys = params["experiment_keys"] || params[:experiment_keys] || []
    attributes = params["attributes"] || params[:attributes] || %{}

    assignments =
      experiment_keys
      |> Enum.take(50)
      |> Enum.map(fn key ->
        case assign(tenant_id, %{
               "user_id" => user_id,
               "experiment_key" => key,
               "attributes" => attributes
             }) do
          {:ok, result} ->
            result

          {:error, :experiment_not_found} ->
            %{experiment_key: key, error: "experiment_not_found"}
        end
      end)

    {:ok, %{user_id: user_id, assignments: assignments, assigned_at: DateTime.utc_now()}}
  end

  @doc """
  Get an override for a specific user + experiment.
  """
  def get_override(tenant_id, experiment_id, user_id) do
    query =
      from(o in AssignmentOverride,
        where: o.tenant_id == ^tenant_id,
        where: o.experiment_id == ^experiment_id,
        where: o.user_id == ^user_id
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      override -> {:ok, override}
    end
  end

  @doc """
  Create an assignment override for QA/testing.
  """
  def create_override(attrs) do
    %AssignmentOverride{}
    |> AssignmentOverride.changeset(attrs)
    |> Repo.insert()
  end

  # Private assignment logic

  defp do_assign(tenant_id, experiment, user_id, _attributes) do
    # 1. Check for override
    case get_override(tenant_id, experiment.id, user_id) do
      {:ok, override} ->
        variant = find_variant_by_id(experiment, override.variant_id)
        build_result(experiment, variant, user_id, tenant_id, true, "override")

      {:error, :not_found} ->
        # 2. Check for persisted assignment (flip-flop prevention)
        case AssignmentPersistence.get_existing(tenant_id, experiment.id, user_id) do
          {:ok, assignment} ->
            variant = find_variant_by_id(experiment, assignment.variant_id)
            build_result(experiment, variant, user_id, tenant_id, true, "persisted")

          {:error, :not_found} ->
            # 3. Hash-based assignment
            hash_and_persist(tenant_id, experiment, user_id)
        end
    end
  end

  defp hash_and_persist(tenant_id, experiment, user_id) do
    sorted_variants = Enum.sort_by(experiment.variants, & &1.sort_order)
    allocations = Enum.map(sorted_variants, & &1.traffic_allocation)

    variant_index =
      case nif_assign_variant(user_id, experiment.key, allocations) do
        {:ok, index} ->
          index

        :error ->
          # Fallback: pure Elixir hash if NIF not loaded
          elixir_assign(user_id, experiment.key, allocations)
      end

    variant = Enum.at(sorted_variants, variant_index) || List.first(sorted_variants)

    # Persist to prevent flip-flop
    AssignmentPersistence.persist(%{
      tenant_id: tenant_id,
      experiment_id: experiment.id,
      variant_id: variant.id,
      user_id: user_id
    })

    result = build_result(experiment, variant, user_id, tenant_id, true, "hash")

    case result do
      {:ok, r} ->
        EventPublisher.publish_assignment(r)
        {:ok, r}

      other ->
        other
    end
  end

  defp elixir_assign(user_id, experiment_key, allocations) do
    hash_input = "#{experiment_key}:#{user_id}"
    <<hash::unsigned-integer-size(128)>> = :crypto.hash(:md5, hash_input)
    bucket = rem(hash, 10_000)

    allocations
    |> Enum.reduce_while({0, 0}, fn alloc, {cumulative, idx} ->
      new_cumulative = cumulative + alloc

      if bucket < new_cumulative do
        {:halt, {new_cumulative, idx}}
      else
        {:cont, {new_cumulative, idx + 1}}
      end
    end)
    |> elem(1)
  end

  defp nif_assign_variant(user_id, experiment_key, allocations) do
    module = Module.concat([AssignmentEngine, Native])

    if Code.ensure_loaded?(module) and function_exported?(module, :assign_variant, 3) do
      try do
        {:ok, apply(module, :assign_variant, [user_id, experiment_key, allocations])}
      rescue
        _ -> :error
      end
    else
      :error
    end
  end

  defp fallback_result(experiment, user_id, reason) do
    control_variant =
      Enum.find(experiment.variants, fn v -> v.is_control end) ||
        List.first(experiment.variants)

    {:ok,
     %{
       experiment_key: experiment.key,
       experiment_id: experiment.id,
       variant_key: control_variant && control_variant.key,
       variant_name: control_variant && control_variant.name,
       variant_id: control_variant && control_variant.id,
       is_control: true,
       enrolled: false,
       user_id: user_id,
       tenant_id: experiment.tenant_id,
       reason: reason,
       source: "fallback",
       assigned_at: DateTime.utc_now()
     }}
  end

  defp build_result(experiment, variant, user_id, tenant_id, enrolled, source) do
    {:ok,
     %{
       experiment_key: experiment.key,
       experiment_id: experiment.id,
       variant_key: variant.key,
       variant_name: variant.name,
       variant_id: variant.id,
       is_control: variant.is_control,
       enrolled: enrolled,
       user_id: user_id,
       tenant_id: tenant_id,
       source: source,
       assigned_at: DateTime.utc_now()
     }}
  end

  defp find_variant_by_id(experiment, variant_id) do
    Enum.find(experiment.variants, fn v -> v.id == variant_id end) ||
      List.first(experiment.variants)
  end
end
