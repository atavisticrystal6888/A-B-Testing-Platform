defmodule ExperimentHub.Notifications do
  @moduledoc """
  Enqueues outbound alert notifications. Callers stay decoupled from
  whether Oban is running or a webhook is configured — notify_async/2
  degrades to a no-op in both cases rather than raising.
  """

  alias ExperimentHub.Workers.NotificationWorker

  @doc """
  Enqueues delivery of an alert webhook for `event_type` with `payload`.
  Mirrors the schedule_analysis/1 pattern in ExperimentHub.Experiments:
  same Oban-availability guard, same graceful degradation.
  """
  def notify_async(event_type, payload) when is_binary(event_type) and is_map(payload) do
    if Application.get_env(:experiment_hub, :start_oban, true) do
      try do
        Oban.insert(NotificationWorker.new(%{"event_type" => event_type, "payload" => payload}))
      rescue
        error -> {:error, error}
      catch
        :exit, reason -> {:error, reason}
      end
    else
      {:error, :disabled}
    end
  end
end
