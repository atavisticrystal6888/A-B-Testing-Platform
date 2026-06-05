defmodule ExperimentHub.Experiments.WorkflowIntegrationTest do
  @moduledoc """
  Integration test for the full experiment creation workflow:
  create metric → create experiment → attach metric → launch
  """
  use ExperimentHub.DataCase

  alias ExperimentHub.Experiments
  alias ExperimentHub.Metrics
  alias ExperimentHub.Repo

  describe "full experiment lifecycle workflow" do
    setup do
      tenant = tenant_fixture()
      Repo.put_tenant_id(tenant.id)
      %{tenant: tenant}
    end

    test "create metric → create experiment → attach metric → launch", %{tenant: tenant} do
      # Step 1: Create a metric definition
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "checkout-conversion",
          "name" => "Checkout Conversion",
          "metric_type" => "count",
          "definition" => %{"event_name" => "checkout_completed"}
        })

      assert metric_def.key == "checkout-conversion"

      # Step 2: Create an experiment with variants
      {:ok, experiment, _warnings} =
        Experiments.create_experiment(%{
          "tenant_id" => tenant.id,
          "key" => "button-color-test",
          "name" => "Button Color Test",
          "hypothesis" => "Green button increases conversions by 5%",
          "feature_tag" => "checkout-page",
          "variants" => [
            %{
              "key" => "control",
              "name" => "Blue Button",
              "is_control" => true,
              "traffic_allocation" => 5000
            },
            %{
              "key" => "treatment",
              "name" => "Green Button",
              "is_control" => false,
              "traffic_allocation" => 5000
            }
          ]
        })

      assert experiment.status == "draft"
      assert length(experiment.variants) == 2

      # Step 3: Attach primary metric
      {:ok, _experiment_metric} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "metric_definition_id" => metric_def.id,
          "role" => "primary"
        })

      # Step 4: Launch the experiment
      experiment = Experiments.get_experiment!(experiment.id)
      {:ok, launched} = Experiments.start_experiment(experiment)

      assert launched.status == "running"
      assert launched.started_at != nil

      # Step 5: Pause the experiment
      {:ok, paused} = Experiments.pause_experiment(launched)
      assert paused.status == "paused"

      # Step 6: Resume the experiment
      {:ok, resumed} = Experiments.resume_experiment(paused)
      assert resumed.status == "running"

      # Step 7: Conclude the experiment
      {:ok, concluded} =
        Experiments.conclude_experiment(resumed, %{
          "conclusion_decision" => "ship_variant",
          "conclusion_rationale" => "Treatment outperformed control"
        })

      assert concluded.status == "concluded"
      assert concluded.conclusion_decision == "ship_variant"
      assert concluded.concluded_at != nil
    end

    test "cannot launch experiment without primary metric", %{tenant: tenant} do
      {:ok, experiment, _warnings} =
        Experiments.create_experiment(%{
          "tenant_id" => tenant.id,
          "key" => "no-metric-test",
          "name" => "No Metric Test",
          "hypothesis" => "Testing without metric",
          "variants" => [
            %{
              "key" => "control",
              "name" => "Control",
              "is_control" => true,
              "traffic_allocation" => 5000
            },
            %{
              "key" => "treatment",
              "name" => "Treatment",
              "is_control" => false,
              "traffic_allocation" => 5000
            }
          ]
        })

      experiment = Experiments.get_experiment!(experiment.id)
      assert {:error, violations} = Experiments.start_experiment(experiment)
      assert "primary_metric_required" in violations
    end

    test "cannot launch experiment without hypothesis", %{tenant: tenant} do
      {:ok, metric_def} =
        Metrics.create_metric_definition(%{
          "tenant_id" => tenant.id,
          "key" => "test-metric-no-hyp",
          "name" => "Test Metric",
          "metric_type" => "count",
          "definition" => %{"event_name" => "test"}
        })

      {:ok, experiment, _warnings} =
        Experiments.create_experiment(%{
          "tenant_id" => tenant.id,
          "key" => "no-hypothesis-test",
          "name" => "No Hypothesis Test",
          "variants" => [
            %{
              "key" => "control",
              "name" => "Control",
              "is_control" => true,
              "traffic_allocation" => 5000
            },
            %{
              "key" => "treatment",
              "name" => "Treatment",
              "is_control" => false,
              "traffic_allocation" => 5000
            }
          ]
        })

      {:ok, _} =
        Metrics.attach_metric(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "metric_definition_id" => metric_def.id,
          "role" => "primary"
        })

      experiment = Experiments.get_experiment!(experiment.id)
      assert {:error, violations} = Experiments.start_experiment(experiment)
      assert "hypothesis_required" in violations
    end

    test "cannot conclude a draft experiment", %{tenant: tenant} do
      {:ok, experiment, _warnings} =
        Experiments.create_experiment(%{
          "tenant_id" => tenant.id,
          "key" => "draft-conclude-test",
          "name" => "Draft Conclude Test",
          "hypothesis" => "Test hypothesis",
          "variants" => [
            %{
              "key" => "control",
              "name" => "Control",
              "is_control" => true,
              "traffic_allocation" => 5000
            },
            %{
              "key" => "treatment",
              "name" => "Treatment",
              "is_control" => false,
              "traffic_allocation" => 5000
            }
          ]
        })

      assert {:error, _message} =
               Experiments.conclude_experiment(experiment, %{
                 "conclusion_decision" => "ship_variant"
               })
    end

    test "overlap detection returns warnings for same feature_tag", %{tenant: tenant} do
      # Create a running experiment
      {:ok, _exp1, _} =
        Experiments.create_experiment(%{
          "tenant_id" => tenant.id,
          "key" => "exp-running-overlap",
          "name" => "Running Overlap",
          "hypothesis" => "Hypothesis 1",
          "feature_tag" => "checkout-page",
          "status" => "running",
          "variants" => [
            %{
              "key" => "control",
              "name" => "Control",
              "is_control" => true,
              "traffic_allocation" => 5000
            },
            %{
              "key" => "treatment",
              "name" => "Treatment",
              "is_control" => false,
              "traffic_allocation" => 5000
            }
          ]
        })

      # Create another experiment with the same feature_tag
      {:ok, _exp2, warnings} =
        Experiments.create_experiment(%{
          "tenant_id" => tenant.id,
          "key" => "exp-new-overlap",
          "name" => "New Overlap",
          "hypothesis" => "Hypothesis 2",
          "feature_tag" => "checkout-page",
          "variants" => [
            %{
              "key" => "control",
              "name" => "Control",
              "is_control" => true,
              "traffic_allocation" => 5000
            },
            %{
              "key" => "treatment",
              "name" => "Treatment",
              "is_control" => false,
              "traffic_allocation" => 5000
            }
          ]
        })

      assert length(warnings) == 1
      assert hd(warnings).type == "experiment_overlap"
    end
  end
end
