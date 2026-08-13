defmodule ExperimentHub.DemoSeeds do
  @moduledoc """
  Idempotent development data for the interactive ExperimentHub demo.

  The demo intentionally exercises the same schemas and contexts used by the
  management API, so dashboard views and API examples have representative data.
  """

  import Ecto.Query

  alias ExperimentHub.{AuditLog, DevSeeds, Experiments, FeatureFlags, Metrics, Repo, Tenants}
  alias ExperimentHub.Assignments.Assignment
  alias ExperimentHub.Events.ExperimentEvent

  alias ExperimentHub.Experiments.{
    ExclusionGroup,
    ExclusionGroupExperiment,
    Experiment,
    ExperimentGroups,
    Variant
  }

  alias ExperimentHub.FeatureFlags.Flag

  alias ExperimentHub.Metrics.{
    ExperimentMetric,
    ExperimentResultDaily,
    MetricDefinition,
    StatisticalAnalysis
  }

  alias ExperimentHub.Tenants.{ApiKey, User}
  alias ExperimentHub.Workers.PartitionManagerWorker

  @demo_user_password "DemoP@ssword123"
  @demo_api_key_name "Demo SDK Key"

  @demo_users %{
    analyst: %{"email" => "analyst@local.dev", "role" => "editor"},
    operator: %{"email" => "operator@local.dev", "role" => "editor"},
    viewer: %{"email" => "viewer@local.dev", "role" => "viewer"}
  }

  @doc """
  Seeds a complete local demo workspace and returns the generated credentials
  and primary records. This function is safe to run repeatedly in development.
  """
  def seed! do
    %{tenant: tenant, user: admin, password: admin_password} = DevSeeds.seed_local_admin!()
    ensure_current_partitions!()

    try do
      case Repo.transaction(fn ->
             Repo.put_tenant_id(tenant.id)

             users = ensure_users!(tenant)
             metrics = ensure_metrics!(tenant)
             experiments = ensure_experiments!(tenant, metrics, admin)
             group = ensure_experiment_group!(tenant, experiments)
             flags = ensure_flags!(tenant)

             seed_assignments!(tenant, experiments)
             seed_events!(tenant, experiments)
             seed_daily_results!(tenant, experiments, metrics)
             seed_analyses!(tenant, experiments, metrics)
             seed_audit_logs!(tenant, admin, experiments)

             api_key = rotate_demo_api_key!(tenant)

             %{
               tenant: tenant,
               admin: admin,
               users: users,
               metrics: metrics,
               experiments: experiments,
               group: group,
               flags: flags,
               api_key: api_key
             }
           end) do
        {:ok, demo} ->
          Map.merge(demo, %{
            admin_password: admin_password,
            demo_user_password: @demo_user_password
          })

        {:error, reason} ->
          raise "demo seed failed: #{inspect(reason)}"
      end
    after
      Repo.clear_tenant_id()
    end
  end

  defp ensure_current_partitions! do
    if Mix.env() == :dev do
      :ok = PartitionManagerWorker.perform(%Oban.Job{args: %{}})
    else
      :ok
    end
  end

  defp ensure_users!(tenant) do
    Map.new(@demo_users, fn {name, attrs} ->
      user =
        case Tenants.get_user_by_email(tenant.id, attrs["email"]) do
          nil ->
            create_user!(Map.put(attrs, "tenant_id", tenant.id))

          %User{} = existing ->
            existing
            |> update_user!(attrs)
            |> update_user_password!(%{"password" => @demo_user_password})
        end

      {name, user}
    end)
  end

  defp create_user!(attrs) do
    case Tenants.create_user(Map.put(attrs, "password", @demo_user_password)) do
      {:ok, user} -> user
      {:error, changeset} -> raise "demo user seed failed: #{inspect(changeset.errors)}"
    end
  end

  defp update_user!(user, attrs) do
    case Tenants.update_user(user, attrs) do
      {:ok, updated} -> updated
      {:error, changeset} -> raise "demo user update failed: #{inspect(changeset.errors)}"
    end
  end

  defp update_user_password!(user, attrs) do
    case Tenants.update_user_password(user, attrs) do
      {:ok, updated} ->
        updated

      {:error, changeset} ->
        raise "demo user password update failed: #{inspect(changeset.errors)}"
    end
  end

  defp ensure_metrics!(tenant) do
    metric_specs()
    |> Enum.map(fn spec -> {spec.key, ensure_metric!(tenant, spec)} end)
    |> Map.new()
  end

  defp metric_specs do
    [
      %{
        key: "checkout_conversion",
        name: "Checkout Conversion",
        description: "Completed checkout events divided by assigned visitors.",
        metric_type: "ratio",
        definition: %{
          "event_name" => "checkout_completed",
          "numerator" => "conversion",
          "denominator" => "assignment"
        }
      },
      %{
        key: "average_order_value",
        name: "Average Order Value",
        description: "Mean revenue captured after a completed checkout.",
        metric_type: "sum",
        definition: %{"event_name" => "order_completed", "value_field" => "value"}
      },
      %{
        key: "checkout_error_rate",
        name: "Checkout Error Rate",
        description: "Payment or validation failures observed during checkout.",
        metric_type: "ratio",
        definition: %{"event_name" => "checkout_error", "numerator" => "errors"}
      }
    ]
  end

  defp ensure_metric!(tenant, spec) do
    attrs = %{
      "tenant_id" => tenant.id,
      "key" => spec.key,
      "name" => spec.name,
      "description" => spec.description,
      "metric_type" => spec.metric_type,
      "definition" => spec.definition
    }

    case Metrics.get_metric_definition_by_key(tenant.id, spec.key) do
      nil ->
        case Metrics.create_metric_definition(attrs) do
          {:ok, metric} -> metric
          {:error, changeset} -> raise "demo metric seed failed: #{inspect(changeset.errors)}"
        end

      %MetricDefinition{} = metric ->
        case Metrics.update_metric_definition(metric, attrs) do
          {:ok, updated} -> updated
          {:error, changeset} -> raise "demo metric update failed: #{inspect(changeset.errors)}"
        end
    end
  end

  defp ensure_experiments!(tenant, metrics, admin) do
    checkout =
      tenant
      |> ensure_experiment!(checkout_spec())
      |> ensure_metric_attachments!(tenant, [
        {metrics["checkout_conversion"], "primary", %{}},
        {metrics["average_order_value"], "secondary", %{}},
        {metrics["checkout_error_rate"], "guardrail", %{threshold: "0.03", direction: "above"}}
      ])
      |> transition_to!("running", admin.id)

    pricing =
      tenant
      |> ensure_experiment!(pricing_spec())
      |> ensure_metric_attachments!(tenant, [
        {metrics["checkout_conversion"], "primary", %{}},
        {metrics["average_order_value"], "secondary", %{}}
      ])
      |> transition_to!("paused", admin.id)

    search =
      tenant
      |> ensure_experiment!(search_spec())
      |> ensure_metric_attachments!(tenant, [{metrics["checkout_conversion"], "primary", %{}}])
      |> transition_to!("concluded", admin.id)

    onboarding =
      tenant
      |> ensure_experiment!(onboarding_spec())
      |> ensure_metric_attachments!(tenant, [{metrics["checkout_conversion"], "primary", %{}}])

    %{checkout: checkout, pricing: pricing, search: search, onboarding: onboarding}
  end

  defp checkout_spec do
    %{
      key: "checkout-copy-demo",
      name: "Checkout Copy Demo",
      description: "A concise checkout reassurance message versus the current copy.",
      hypothesis: "A clear delivery reassurance message will increase completed checkouts.",
      feature_tag: "checkout",
      variants: [
        variant_spec("control", "Current Checkout", true, 5_000, 0),
        variant_spec("reassurance-copy", "Delivery Reassurance", false, 5_000, 1)
      ]
    }
  end

  defp pricing_spec do
    %{
      key: "pricing-layout-demo",
      name: "Pricing Layout Demo",
      description: "A paused pricing-card layout comparison for review.",
      hypothesis: "Showing annual savings beside the monthly price will improve checkout starts.",
      feature_tag: "pricing",
      variants: [
        variant_spec("control", "Current Pricing", true, 5_000, 0),
        variant_spec("annual-savings", "Annual Savings Callout", false, 5_000, 1)
      ]
    }
  end

  defp search_spec do
    %{
      key: "search-ranking-demo",
      name: "Search Ranking Demo",
      description: "A concluded ranking experiment with a winning treatment.",
      hypothesis: "Boosting in-stock products will improve completed purchases from search.",
      feature_tag: "search",
      variants: [
        variant_spec("control", "Current Ranking", true, 5_000, 0),
        variant_spec("in-stock-boost", "In-stock Boost", false, 5_000, 1)
      ]
    }
  end

  defp onboarding_spec do
    %{
      key: "onboarding-flow-demo",
      name: "Onboarding Flow Demo",
      description: "A draft activation flow ready for stakeholder review.",
      hypothesis: "A guided three-step setup will improve first-session activation.",
      feature_tag: "onboarding",
      variants: [
        variant_spec("control", "Current Onboarding", true, 5_000, 0),
        variant_spec("guided-setup", "Guided Setup", false, 5_000, 1)
      ]
    }
  end

  defp variant_spec(key, name, is_control, traffic_allocation, sort_order) do
    %{
      "key" => key,
      "name" => name,
      "is_control" => is_control,
      "traffic_allocation" => traffic_allocation,
      "sort_order" => sort_order
    }
  end

  defp ensure_experiment!(tenant, spec) do
    experiment =
      case Repo.get_by(Experiment, tenant_id: tenant.id, key: spec.key) do
        nil ->
          attrs = %{
            "tenant_id" => tenant.id,
            "key" => spec.key,
            "name" => spec.name,
            "description" => spec.description,
            "hypothesis" => spec.hypothesis,
            "feature_tag" => spec.feature_tag,
            "variants" => spec.variants
          }

          case Experiments.create_experiment(attrs) do
            {:ok, created, _warnings} ->
              created

            {:error, changeset} ->
              raise "demo experiment seed failed: #{inspect(changeset.errors)}"
          end

        %Experiment{} = existing ->
          existing
      end

    experiment
    |> then(&Experiments.get_experiment!(&1.id))
    |> ensure_variants!(tenant, spec.variants)
  end

  defp ensure_variants!(experiment, tenant, variant_specs) do
    existing_by_key = Map.new(experiment.variants, &{&1.key, &1})

    Enum.each(variant_specs, fn spec ->
      attrs =
        spec
        |> Map.put("tenant_id", tenant.id)
        |> Map.put("experiment_id", experiment.id)

      case Map.get(existing_by_key, spec["key"]) do
        nil ->
          %Variant{}
          |> Variant.changeset(attrs)
          |> Repo.insert!()

        %Variant{} = variant ->
          variant
          |> Variant.changeset(attrs)
          |> Repo.update!()
      end
    end)

    Experiments.get_experiment!(experiment.id)
  end

  defp ensure_metric_attachments!(experiment, tenant, attachments) do
    Enum.each(attachments, fn {metric, role, options} ->
      exists? =
        Repo.exists?(
          from(em in ExperimentMetric,
            where:
              em.tenant_id == ^tenant.id and em.experiment_id == ^experiment.id and
                em.metric_definition_id == ^metric.id
          )
        )

      unless exists? do
        attrs = %{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "metric_definition_id" => metric.id,
          "role" => role,
          "guardrail_threshold" => options[:threshold],
          "guardrail_direction" => options[:direction]
        }

        case Metrics.attach_metric(attrs) do
          {:ok, _experiment_metric} -> :ok
          {:error, reason} -> raise "demo metric attachment failed: #{inspect(reason)}"
        end
      end
    end)

    Experiments.get_experiment!(experiment.id)
  end

  defp transition_to!(experiment, desired_status, admin_id) do
    experiment = Experiments.get_experiment!(experiment.id)

    case {experiment.status, desired_status} do
      {status, status} ->
        experiment

      {"draft", "running"} ->
        start_experiment!(experiment)

      {"draft", "paused"} ->
        experiment |> start_experiment!() |> pause_experiment!()

      {"running", "paused"} ->
        pause_experiment!(experiment)

      {"paused", "running"} ->
        resume_experiment!(experiment)

      {"draft", "concluded"} ->
        experiment |> start_experiment!() |> conclude_experiment!(admin_id)

      {"running", "concluded"} ->
        conclude_experiment!(experiment, admin_id)

      {"paused", "concluded"} ->
        conclude_experiment!(experiment, admin_id)

      {current, desired} ->
        raise "cannot seed #{experiment.key} from #{current} to #{desired}"
    end
  end

  defp start_experiment!(experiment) do
    case Experiments.start_experiment(experiment) do
      {:ok, updated} -> Experiments.get_experiment!(updated.id)
      {:error, reason} -> raise "demo experiment start failed: #{inspect(reason)}"
    end
  end

  defp pause_experiment!(experiment) do
    case Experiments.pause_experiment(experiment) do
      {:ok, updated} -> Experiments.get_experiment!(updated.id)
      {:error, reason} -> raise "demo experiment pause failed: #{inspect(reason)}"
    end
  end

  defp resume_experiment!(experiment) do
    case Experiments.resume_experiment(experiment) do
      {:ok, updated} -> Experiments.get_experiment!(updated.id)
      {:error, reason} -> raise "demo experiment resume failed: #{inspect(reason)}"
    end
  end

  defp conclude_experiment!(experiment, admin_id) do
    winning_variant = Enum.find(experiment.variants, &(!&1.is_control))

    attrs = %{
      "conclusion_decision" => "ship_variant",
      "conclusion_rationale" => "The seeded treatment has a statistically significant uplift.",
      "winner_variant_id" => winning_variant.id,
      "concluded_by" => admin_id
    }

    case Experiments.conclude_experiment(experiment, attrs) do
      {:ok, updated} -> Experiments.get_experiment!(updated.id)
      {:error, reason} -> raise "demo experiment conclusion failed: #{inspect(reason)}"
    end
  end

  defp ensure_experiment_group!(tenant, experiments) do
    group =
      case Repo.get_by(ExclusionGroup, tenant_id: tenant.id, name: "Checkout Experience") do
        nil ->
          case ExperimentGroups.create_group(%{
                 "tenant_id" => tenant.id,
                 "name" => "Checkout Experience",
                 "description" => "Prevents overlap between checkout and pricing treatments."
               }) do
            {:ok, created} ->
              created

            {:error, changeset} ->
              raise "demo experiment group failed: #{inspect(changeset.errors)}"
          end

        %ExclusionGroup{} = existing ->
          existing
      end

    Enum.each([experiments.checkout, experiments.pricing], fn experiment ->
      member_exists? =
        Repo.exists?(
          from(member in ExclusionGroupExperiment,
            where:
              member.exclusion_group_id == ^group.id and member.experiment_id == ^experiment.id
          ),
          skip_tenant_scope: true
        )

      unless member_exists? do
        case ExperimentGroups.add_experiment(group.id, experiment.id) do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            raise "demo experiment group membership failed: #{inspect(changeset.errors)}"
        end
      end
    end)

    ExperimentGroups.get_group!(group.id)
  end

  defp ensure_flags!(tenant) do
    flag_specs()
    |> Enum.map(fn spec -> {spec.key, ensure_flag!(tenant, spec)} end)
    |> Map.new()
  end

  defp flag_specs do
    [
      %{
        key: "checkout_reassurance",
        name: "Checkout Reassurance",
        description: "Enables the checkout reassurance treatment for the demo.",
        status: "enabled",
        rollout_percentage: 5_000,
        targeting_rules: [
          %{"attribute" => "country", "operator" => "in", "values" => ["US", "CA"]}
        ]
      },
      %{
        key: "search_in_stock_boost",
        name: "Search In-stock Boost",
        description: "Rolls out the winning in-stock ranking treatment.",
        status: "enabled",
        rollout_percentage: 10_000,
        targeting_rules: []
      },
      %{
        key: "guided_onboarding",
        name: "Guided Onboarding",
        description: "Reserved for the upcoming onboarding experiment.",
        status: "disabled",
        rollout_percentage: 0,
        targeting_rules: []
      }
    ]
  end

  defp ensure_flag!(tenant, spec) do
    attrs = %{
      "tenant_id" => tenant.id,
      "key" => spec.key,
      "name" => spec.name,
      "description" => spec.description,
      "status" => spec.status,
      "rollout_percentage" => spec.rollout_percentage,
      "targeting_rules" => spec.targeting_rules,
      "metadata" => %{"source" => "demo_seed"}
    }

    case FeatureFlags.get_flag_by_key(tenant.id, spec.key) do
      nil ->
        case FeatureFlags.create_flag(attrs) do
          {:ok, flag} -> flag
          {:error, changeset} -> raise "demo flag seed failed: #{inspect(changeset.errors)}"
        end

      %Flag{} = flag ->
        case FeatureFlags.update_flag(flag, attrs) do
          {:ok, updated} -> updated
          {:error, changeset} -> raise "demo flag update failed: #{inspect(changeset.errors)}"
        end
    end
  end

  defp seed_assignments!(tenant, experiments) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    seed_assignments_for!(tenant, experiments.checkout, 24, now)
    seed_assignments_for!(tenant, experiments.pricing, 12, now)
    seed_assignments_for!(tenant, experiments.search, 18, now)
  end

  defp seed_assignments_for!(tenant, experiment, count, now) do
    variants = Enum.sort_by(experiment.variants, & &1.sort_order)

    Enum.each(1..count, fn index ->
      variant = Enum.at(variants, rem(index, length(variants)))

      %Assignment{}
      |> Assignment.changeset(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" =>
          "demo-#{experiment.key}-user-#{String.pad_leading(to_string(index), 3, "0")}",
        "assigned_at" => DateTime.add(now, -index * 60, :second)
      })
      |> Repo.insert!(on_conflict: :nothing)
    end)
  end

  defp seed_events!(tenant, experiments) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    seed_events_for!(tenant, experiments.checkout, 24, now)
    seed_events_for!(tenant, experiments.search, 18, now)
  end

  defp seed_events_for!(tenant, experiment, count, now) do
    variants = Enum.sort_by(experiment.variants, & &1.sort_order)

    Enum.each(1..count, fn index ->
      variant = Enum.at(variants, rem(index, length(variants)))
      user_id = "demo-#{experiment.key}-user-#{String.pad_leading(to_string(index), 3, "0")}"
      timestamp = DateTime.add(now, -index * 120, :second)

      insert_demo_event!(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" => user_id,
        "event_type" => "conversion",
        "event_name" => "checkout_completed",
        "idempotency_key" => "demo:#{experiment.key}:#{index}:conversion",
        "timestamp" => timestamp,
        "properties" => %{"source" => "demo_seed", "channel" => "web"}
      })

      insert_demo_event!(%{
        "tenant_id" => tenant.id,
        "experiment_id" => experiment.id,
        "variant_id" => variant.id,
        "user_id" => user_id,
        "event_type" => "revenue",
        "event_name" => "order_completed",
        "value" => 75 + rem(index * 7, 30),
        "idempotency_key" => "demo:#{experiment.key}:#{index}:revenue",
        "timestamp" => timestamp,
        "properties" => %{"source" => "demo_seed", "currency" => "USD"}
      })
    end)
  end

  defp insert_demo_event!(attrs) do
    %ExperimentEvent{}
    |> ExperimentEvent.changeset(attrs)
    |> Repo.insert!(on_conflict: :nothing)
  end

  defp seed_daily_results!(tenant, experiments, metrics) do
    dates = demo_dates()

    seed_rollups_for!(
      tenant,
      experiments.checkout,
      metrics["checkout_conversion"],
      dates,
      180,
      21
    )

    seed_rollups_for!(
      tenant,
      experiments.checkout,
      metrics["average_order_value"],
      dates,
      180,
      21
    )

    seed_rollups_for!(tenant, experiments.search, metrics["checkout_conversion"], dates, 140, 17)
  end

  defp demo_dates do
    today = Date.utc_today()

    0..min(5, today.day - 1)
    |> Enum.map(&Date.add(today, -&1))
  end

  defp seed_rollups_for!(tenant, experiment, metric, dates, base_sample_size, base_conversions) do
    variants = Enum.sort_by(experiment.variants, & &1.sort_order)

    Enum.each(dates, fn date ->
      Enum.with_index(variants, fn variant, variant_index ->
        sample_size = base_sample_size + variant_index * 12
        conversions = base_conversions + variant_index * 8
        average_value = 82 + variant_index * 9

        %ExperimentResultDaily{}
        |> ExperimentResultDaily.changeset(%{
          "tenant_id" => tenant.id,
          "experiment_id" => experiment.id,
          "variant_id" => variant.id,
          "metric_definition_id" => metric.id,
          "date" => date,
          "sample_size" => sample_size,
          "conversions" => conversions,
          "sum_value" => sample_size * average_value,
          "sum_squared_value" => sample_size * average_value * average_value
        })
        |> Repo.insert!(on_conflict: :nothing)
      end)
    end)
  end

  defp seed_analyses!(tenant, experiments, metrics) do
    checkout_variants = Enum.sort_by(experiments.checkout.variants, & &1.sort_order)
    search_variants = Enum.sort_by(experiments.search.variants, & &1.sort_order)

    [
      {experiments.checkout, metrics["checkout_conversion"],
       primary_result(
         "checkout_conversion",
         checkout_variants,
         "reassurance-copy",
         0.018,
         0.18,
         0.0124
       )},
      {experiments.checkout, metrics["average_order_value"],
       secondary_result("average_order_value", checkout_variants)},
      {experiments.checkout, metrics["checkout_error_rate"],
       guardrail_result("checkout_error_rate")},
      {experiments.search, metrics["checkout_conversion"],
       primary_result(
         "checkout_conversion",
         search_variants,
         "in-stock-boost",
         0.022,
         0.22,
         0.0041
       )}
    ]
    |> Enum.each(fn {experiment, metric, result} ->
      ensure_analysis!(tenant, experiment, metric, result)
    end)
  end

  defp ensure_analysis!(tenant, experiment, metric, result) do
    attrs = %{
      "tenant_id" => tenant.id,
      "experiment_id" => experiment.id,
      "metric_definition_id" => metric.id,
      "analysis_type" => "frequentist",
      "methodology" => "demo_seed",
      "parameters" => %{"source" => "demo_seed", "significance_level" => 0.05},
      "results" => result,
      "sample_sizes" =>
        result["variants"]
        |> Enum.into(%{}, fn variant -> {variant["variant_key"], variant["sample_size"]} end),
      "is_significant" => get_in(result, ["frequentist", "is_significant"]),
      "winning_variant_id" => winning_variant_id(experiment, result),
      "computed_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    }

    query =
      from(analysis in StatisticalAnalysis,
        where:
          analysis.experiment_id == ^experiment.id and
            analysis.metric_definition_id == ^metric.id and analysis.methodology == "demo_seed"
      )

    case Repo.one(query) do
      nil ->
        %StatisticalAnalysis{}
        |> StatisticalAnalysis.changeset(attrs)
        |> Repo.insert!()

      analysis ->
        analysis
        |> StatisticalAnalysis.changeset(attrs)
        |> Repo.update!()
    end
  end

  defp winning_variant_id(experiment, result) do
    case get_in(result, ["recommendation", "winning_variant"]) do
      nil ->
        nil

      variant_key ->
        Enum.find_value(experiment.variants, fn variant ->
          if variant.key == variant_key, do: variant.id
        end)
    end
  end

  defp primary_result(metric_key, variants, winning_variant_key, absolute, relative, p_value) do
    [control, treatment] = variants

    %{
      "metric_key" => metric_key,
      "metric_type" => "ratio",
      "role" => "primary",
      "variants" => [
        variant_stats(control, 1_080, 108, 0.10),
        variant_stats(treatment, 1_120, 132, 0.1179)
      ],
      "frequentist" => %{
        "test_method" => "two_proportion_z_test",
        "p_value" => p_value,
        "confidence_level" => 0.95,
        "confidence_interval" => %{
          "lower" => absolute - 0.006,
          "upper" => absolute + 0.006,
          "point_estimate" => absolute
        },
        "effect_size" => %{
          "absolute" => absolute,
          "relative" => relative,
          "cohens_h" => 0.061
        },
        "power_achieved" => 0.87,
        "is_significant" => true
      },
      "sequential" => %{
        "spending_function" => "obrien_fleming",
        "information_fraction" => 0.92,
        "nominal_alpha" => 0.025,
        "adjusted_critical_value" => 2.31,
        "observed_z_statistic" => 2.74,
        "can_reject" => true
      },
      "sample_size_calculation" => %{
        "minimum_required" => 1_000,
        "current_total" => 2_200,
        "is_sufficient" => true,
        "baseline_rate" => 0.10,
        "minimum_detectable_effect" => 0.02,
        "power" => 0.80,
        "significance_level" => 0.05
      },
      "recommendation" => %{
        "action" => "significant_winner",
        "winning_variant" => winning_variant_key,
        "confidence" => "high",
        "message" => "The treatment has a statistically significant conversion uplift."
      }
    }
  end

  defp secondary_result(metric_key, variants) do
    [control, treatment] = variants

    %{
      "metric_key" => metric_key,
      "metric_type" => "sum",
      "role" => "secondary",
      "variants" => [
        variant_stats(control, 1_080, nil, nil, 82.40),
        variant_stats(treatment, 1_120, nil, nil, 91.10)
      ],
      "frequentist" => %{
        "test_method" => "welch_t_test",
        "p_value" => 0.031,
        "confidence_level" => 0.95,
        "confidence_interval" => %{"lower" => 1.7, "upper" => 15.7, "point_estimate" => 8.7},
        "effect_size" => %{"absolute" => 8.7, "relative" => 0.1056},
        "power_achieved" => 0.82,
        "is_significant" => true
      },
      "sample_size_calculation" => %{
        "minimum_required" => 1_000,
        "current_total" => 2_200,
        "is_sufficient" => true
      },
      "recommendation" => %{
        "action" => "supporting_evidence",
        "message" => "Average order value also improved for the treatment."
      }
    }
  end

  defp guardrail_result(metric_key) do
    %{
      "metric_key" => metric_key,
      "metric_type" => "ratio",
      "role" => "guardrail",
      "variants" => [],
      "guardrail_status" => %{
        "threshold" => 0.03,
        "direction" => "above",
        "current_value" => 0.012,
        "is_breached" => false
      }
    }
  end

  defp variant_stats(variant, sample_size, conversions, conversion_rate, mean \\ nil) do
    %{
      "variant_key" => variant.key,
      "sample_size" => sample_size,
      "conversions" => conversions,
      "conversion_rate" => conversion_rate,
      "mean" => mean
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp seed_audit_logs!(tenant, admin, experiments) do
    resource_ids = [experiments.checkout.id, experiments.pricing.id, experiments.search.id]

    from(log in AuditLog,
      where:
        log.tenant_id == ^tenant.id and log.resource_id in ^resource_ids and
          log.reason == "demo_seed"
    )
    |> Repo.delete_all()

    [
      {experiments.checkout, "started", "Checkout treatment is live for the demo."},
      {experiments.pricing, "paused", "Pricing review is waiting for stakeholder sign-off."},
      {experiments.search, "concluded", "In-stock ranking won the seeded analysis."}
    ]
    |> Enum.each(fn {experiment, action, reason} ->
      AuditLog.log_experiment_change(experiment, action,
        actor_id: admin.id,
        actor_type: "user",
        reason: "demo_seed",
        changes: %{status: %{to: experiment.status}, note: reason}
      )
    end)
  end

  defp rotate_demo_api_key!(tenant) do
    from(api_key in ApiKey,
      where: api_key.tenant_id == ^tenant.id and api_key.name == ^@demo_api_key_name
    )
    |> Repo.delete_all()

    case Tenants.create_api_key(%{"tenant_id" => tenant.id, "name" => @demo_api_key_name}) do
      {:ok, api_key} -> api_key
      {:error, changeset} -> raise "demo API key seed failed: #{inspect(changeset.errors)}"
    end
  end
end
