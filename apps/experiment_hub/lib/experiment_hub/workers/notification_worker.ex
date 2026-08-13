defmodule ExperimentHub.Workers.NotificationWorker do
  @moduledoc """
  Oban worker that delivers an outbound alert webhook. Kept off the
  triggering worker's request path (AnalysisWorker, GuardrailWorker) so a
  slow or down webhook endpoint can't delay analysis storage or guardrail
  enforcement, and retries (max_attempts) are handled by Oban rather than
  the caller.
  """
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias ExperimentHub.Notifications.WebhookClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_type" => event_type, "payload" => payload}}) do
    WebhookClient.deliver(event_type, payload)
  end
end
