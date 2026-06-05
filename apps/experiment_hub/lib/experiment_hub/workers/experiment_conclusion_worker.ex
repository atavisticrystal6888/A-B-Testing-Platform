defmodule ExperimentHub.Workers.ExperimentConclusionWorker do
  @moduledoc """
  Oban worker for auto-concluding experiments past max duration (FR-067).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias ExperimentHub.Experiments.ConclusionService

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    results = ConclusionService.auto_conclude_expired()

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      :ok
    else
      {:error, "#{length(errors)} experiments failed to auto-conclude"}
    end
  end
end
