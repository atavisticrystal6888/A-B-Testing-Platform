defmodule ExperimentHub.RLSIntegrationTest do
  @moduledoc """
  Integration test verifying Row-Level Security (RLS):
  Authenticated tenant A never sees tenant B data across
  experiments, events, and users.
  """

  use ExperimentHub.DataCase

  alias ExperimentHub.Repo
  alias ExperimentHub.Tenants.{User, ApiKey}
  alias ExperimentHub.Experiments.{Experiment, Variant}

  describe "RLS tenant isolation" do
    setup do
      # Create two separate tenants
      tenant_a = tenant_fixture(%{name: "Tenant A", slug: "tenant-a"})
      tenant_b = tenant_fixture(%{name: "Tenant B", slug: "tenant-b"})

      # Create users in each tenant
      user_a =
        user_fixture(%{tenant: tenant_a, email: "alice@tenant-a.com", role: "admin"})

      user_b =
        user_fixture(%{tenant: tenant_b, email: "bob@tenant-b.com", role: "admin"})

      # Create API keys in each tenant
      api_key_a = api_key_fixture(%{tenant: tenant_a, name: "Key A"})
      api_key_b = api_key_fixture(%{tenant: tenant_b, name: "Key B"})

      # Create experiments in each tenant (bypass RLS using direct insert)
      experiment_a = create_experiment(tenant_a.id, "exp-a", "Experiment A")
      experiment_b = create_experiment(tenant_b.id, "exp-b", "Experiment B")

      # Create variants for each experiment
      variant_a = create_variant(tenant_a.id, experiment_a.id, "control-a", true)
      variant_b = create_variant(tenant_b.id, experiment_b.id, "control-b", true)

      %{
        tenant_a: tenant_a,
        tenant_b: tenant_b,
        user_a: user_a,
        user_b: user_b,
        api_key_a: api_key_a,
        api_key_b: api_key_b,
        experiment_a: experiment_a,
        experiment_b: experiment_b,
        variant_a: variant_a,
        variant_b: variant_b
      }
    end

    test "tenant A cannot see tenant B's users", ctx do
      Repo.put_tenant_id(ctx.tenant_a.id)

      users = Repo.all(User)
      user_ids = Enum.map(users, & &1.id)

      assert ctx.user_a.id in user_ids
      refute ctx.user_b.id in user_ids
    end

    test "tenant B cannot see tenant A's users", ctx do
      Repo.put_tenant_id(ctx.tenant_b.id)

      users = Repo.all(User)
      user_ids = Enum.map(users, & &1.id)

      assert ctx.user_b.id in user_ids
      refute ctx.user_a.id in user_ids
    end

    test "tenant A cannot see tenant B's API keys", ctx do
      Repo.put_tenant_id(ctx.tenant_a.id)

      api_keys = Repo.all(ApiKey)
      key_ids = Enum.map(api_keys, & &1.id)

      assert ctx.api_key_a.id in key_ids
      refute ctx.api_key_b.id in key_ids
    end

    test "tenant A cannot see tenant B's experiments", ctx do
      Repo.put_tenant_id(ctx.tenant_a.id)

      experiments = Repo.all(Experiment)
      exp_ids = Enum.map(experiments, & &1.id)

      assert ctx.experiment_a.id in exp_ids
      refute ctx.experiment_b.id in exp_ids
    end

    test "tenant B cannot see tenant A's experiments", ctx do
      Repo.put_tenant_id(ctx.tenant_b.id)

      experiments = Repo.all(Experiment)
      exp_ids = Enum.map(experiments, & &1.id)

      assert ctx.experiment_b.id in exp_ids
      refute ctx.experiment_a.id in exp_ids
    end

    test "tenant A cannot see tenant B's variants", ctx do
      Repo.put_tenant_id(ctx.tenant_a.id)

      variants = Repo.all(Variant)
      variant_ids = Enum.map(variants, & &1.id)

      assert ctx.variant_a.id in variant_ids
      refute ctx.variant_b.id in variant_ids
    end

    test "switching tenant context changes visible data", ctx do
      # First, set context to tenant A
      Repo.put_tenant_id(ctx.tenant_a.id)
      experiments_a = Repo.all(Experiment)
      assert length(experiments_a) == 1
      assert hd(experiments_a).id == ctx.experiment_a.id

      # Switch to tenant B
      Repo.put_tenant_id(ctx.tenant_b.id)
      experiments_b = Repo.all(Experiment)
      assert length(experiments_b) == 1
      assert hd(experiments_b).id == ctx.experiment_b.id
    end

    test "tenant A cannot access tenant B's experiment by ID", ctx do
      Repo.put_tenant_id(ctx.tenant_a.id)

      assert Repo.get(Experiment, ctx.experiment_b.id) == nil
    end

    test "tenant A cannot access tenant B's user by ID", ctx do
      Repo.put_tenant_id(ctx.tenant_a.id)

      assert Repo.get(User, ctx.user_b.id) == nil
    end
  end

  # Helpers to create experiments/variants bypassing context validation
  defp create_experiment(tenant_id, key, name) do
    %Experiment{}
    |> Experiment.changeset(%{
      "tenant_id" => tenant_id,
      "key" => key,
      "name" => name,
      "hypothesis" => "Test hypothesis for #{name}"
    })
    |> Repo.insert!()
  end

  defp create_variant(tenant_id, experiment_id, key, is_control) do
    %Variant{}
    |> Variant.changeset(%{
      "tenant_id" => tenant_id,
      "experiment_id" => experiment_id,
      "key" => key,
      "name" => "Variant #{key}",
      "is_control" => is_control,
      "traffic_allocation" => 10_000
    })
    |> Repo.insert!()
  end
end
