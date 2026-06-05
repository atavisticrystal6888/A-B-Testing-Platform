defmodule ExperimentHub.Experiments.OverlapDetectorTest do
  use ExperimentHub.DataCase

  alias ExperimentHub.Experiments.OverlapDetector
  alias ExperimentHub.Experiments.Experiment
  alias ExperimentHub.Repo

  describe "check_overlaps/3" do
    test "returns empty list when no feature_tag" do
      tenant = tenant_fixture()
      experiment_id = Ecto.UUID.generate()

      assert [] = OverlapDetector.check_overlaps(experiment_id, nil, tenant.id)
      assert [] = OverlapDetector.check_overlaps(experiment_id, "", tenant.id)
    end

    test "returns empty list when no overlapping running experiments" do
      tenant = tenant_fixture()

      experiment = create_experiment(tenant.id, "exp-1", "Exp 1", "checkout-page", "draft")
      new_experiment_id = Ecto.UUID.generate()

      assert [] = OverlapDetector.check_overlaps(new_experiment_id, "checkout-page", tenant.id)
      # Also verify the draft experiment doesn't trigger overlap
      assert experiment.status == "draft"
    end

    test "returns warnings when running experiment shares feature_tag" do
      tenant = tenant_fixture()

      running_exp =
        create_experiment(tenant.id, "exp-running", "Running Exp", "checkout-page", "running")

      new_experiment_id = Ecto.UUID.generate()

      warnings = OverlapDetector.check_overlaps(new_experiment_id, "checkout-page", tenant.id)

      assert length(warnings) == 1
      warning = hd(warnings)
      assert warning.type == "experiment_overlap"
      assert warning.message =~ "checkout-page"
      assert length(warning.overlapping_experiments) == 1

      overlap = hd(warning.overlapping_experiments)
      assert overlap.id == running_exp.id
      assert overlap.key == "exp-running"
    end

    test "does not include self in overlapping experiments" do
      tenant = tenant_fixture()

      experiment =
        create_experiment(tenant.id, "exp-self", "Self Exp", "checkout-page", "running")

      assert [] = OverlapDetector.check_overlaps(experiment.id, "checkout-page", tenant.id)
    end

    test "returns multiple overlapping experiments" do
      tenant = tenant_fixture()

      create_experiment(tenant.id, "exp-a", "Exp A", "checkout-page", "running")
      create_experiment(tenant.id, "exp-b", "Exp B", "checkout-page", "running")

      new_experiment_id = Ecto.UUID.generate()

      warnings = OverlapDetector.check_overlaps(new_experiment_id, "checkout-page", tenant.id)

      assert length(warnings) == 1
      assert length(hd(warnings).overlapping_experiments) == 2
    end

    test "does not report paused or concluded experiments as overlaps" do
      tenant = tenant_fixture()

      create_experiment(tenant.id, "exp-paused", "Paused", "checkout-page", "paused")
      create_experiment(tenant.id, "exp-concluded", "Concluded", "checkout-page", "concluded")

      new_experiment_id = Ecto.UUID.generate()

      assert [] = OverlapDetector.check_overlaps(new_experiment_id, "checkout-page", tenant.id)
    end

    test "does not report experiments with different feature_tags" do
      tenant = tenant_fixture()

      create_experiment(tenant.id, "exp-other", "Other", "pricing-page", "running")

      new_experiment_id = Ecto.UUID.generate()

      assert [] = OverlapDetector.check_overlaps(new_experiment_id, "checkout-page", tenant.id)
    end
  end

  defp create_experiment(tenant_id, key, name, feature_tag, status) do
    %Experiment{}
    |> Experiment.changeset(%{
      "tenant_id" => tenant_id,
      "key" => key,
      "name" => name,
      "hypothesis" => "Test hypothesis",
      "feature_tag" => feature_tag,
      "status" => status
    })
    |> Repo.insert!()
  end
end
