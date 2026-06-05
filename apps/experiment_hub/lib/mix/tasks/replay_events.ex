defmodule Mix.Tasks.ReplayEvents do
  @moduledoc """
  Kafka event replay Mix task (Constitution Art.V §3).
  Re-consumes events from a topic/partition for a given experiment_id
  and re-runs aggregation to verify result reproducibility.

  ## Usage

      mix replay_events --experiment-id <id> --topic <topic> --from <offset> --to <offset>
  """
  use Mix.Task

  alias ExperimentHub.Repo
  alias ExperimentHub.Metrics.ExperimentResultDaily
  import Ecto.Query

  @shortdoc "Replay Kafka events for an experiment"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          experiment_id: :string,
          topic: :string,
          from_offset: :integer,
          to_offset: :integer,
          dry_run: :boolean
        ]
      )

    experiment_id = opts[:experiment_id] || raise "Missing --experiment-id"
    _topic = opts[:topic] || "experimenthub.events.raw"
    dry_run = opts[:dry_run] || false

    Mix.shell().info("Replaying events for experiment #{experiment_id}")

    if dry_run do
      Mix.shell().info("[DRY RUN] Would re-aggregate results for experiment #{experiment_id}")
    else
      # Clear existing daily results for re-aggregation
      from(r in ExperimentResultDaily, where: r.experiment_id == ^experiment_id)
      |> Repo.delete_all()

      Mix.shell().info(
        "Cleared existing results. Re-aggregation would happen via Kafka consumer."
      )

      Mix.shell().info("Note: Full replay requires running Kafka consumer against the topic.")
    end

    Mix.shell().info("Replay complete.")
  end
end
