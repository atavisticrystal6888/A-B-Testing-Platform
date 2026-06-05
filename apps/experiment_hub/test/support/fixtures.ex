defmodule ExperimentHub.TestFixtures do
  @moduledoc """
  Shared test fixtures (factories) for tenant, user, and api_key creation.
  """

  alias ExperimentHub.Repo
  alias ExperimentHub.Experiments.{Experiment, Variant}
  alias ExperimentHub.Tenants.{Tenant, User, ApiKey, ApiKeyGenerator}

  def tenant_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, tenant} =
      %Tenant{}
      |> Tenant.changeset(
        Map.merge(
          %{
            "name" => "Test Tenant #{unique}",
            "slug" => "test-tenant-#{unique}",
            "settings" => %{}
          },
          stringify_keys(attrs)
        )
      )
      |> Repo.insert()

    tenant
  end

  def user_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tenant = attrs[:tenant] || tenant_fixture()
    unique = System.unique_integer([:positive])

    {:ok, user} =
      %User{}
      |> User.changeset(
        Map.merge(
          %{
            "email" => "user#{unique}@example.com",
            "password" => "password123!",
            "role" => "editor",
            "tenant_id" => tenant.id
          },
          stringify_keys(Map.drop(attrs, [:tenant]))
        )
      )
      |> Repo.insert()

    user
  end

  def api_key_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tenant = attrs[:tenant] || tenant_fixture()
    {raw_key, key_prefix, key_hash} = ApiKeyGenerator.generate()
    unique = System.unique_integer([:positive])

    {:ok, api_key} =
      %ApiKey{}
      |> ApiKey.changeset(
        Map.merge(
          %{
            "name" => "Test Key #{unique}",
            "tenant_id" => tenant.id,
            "key_prefix" => key_prefix,
            "key_hash" => key_hash
          },
          stringify_keys(Map.drop(attrs, [:tenant]))
        )
      )
      |> Repo.insert()

    %{api_key | raw_key: raw_key}
  end

  def experiment_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tenant = attrs[:tenant] || tenant_fixture()
    unique = System.unique_integer([:positive])

    {:ok, experiment} =
      %Experiment{}
      |> Experiment.changeset(
        Map.merge(
          %{
            "tenant_id" => tenant.id,
            "key" => "experiment-#{unique}",
            "name" => "Experiment #{unique}",
            "hypothesis" => "Hypothesis #{unique}",
            "status" => "draft"
          },
          stringify_keys(Map.drop(attrs, [:tenant]))
        )
      )
      |> Repo.insert()

    experiment
  end

  def variant_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    experiment = attrs[:experiment] || experiment_fixture(attrs)
    tenant = attrs[:tenant] || %{id: experiment.tenant_id}
    unique = System.unique_integer([:positive])

    {:ok, variant} =
      %Variant{}
      |> Variant.changeset(
        Map.merge(
          %{
            "tenant_id" => tenant.id,
            "experiment_id" => experiment.id,
            "key" => "variant-#{unique}",
            "name" => "Variant #{unique}",
            "is_control" => true,
            "traffic_allocation" => 10_000,
            "sort_order" => 0
          },
          stringify_keys(Map.drop(attrs, [:tenant, :experiment]))
        )
      )
      |> Repo.insert()

    variant
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
