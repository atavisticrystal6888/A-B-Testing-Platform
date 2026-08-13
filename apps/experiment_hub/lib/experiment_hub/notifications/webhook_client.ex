defmodule ExperimentHub.Notifications.WebhookClient do
  @moduledoc """
  Sends a generic JSON webhook for experiment events (significant analysis
  results, guardrail breaches) to an operator-configured URL. No-ops when
  ALERT_WEBHOOK_URL isn't set — alerting is opt-in.
  """

  require Logger

  @doc """
  Posts `{event: event_type, data: payload, timestamp: ...}` to the
  configured webhook URL. Returns :ok (including when unconfigured, a
  no-op) or {:error, reason} so a wrapping Oban worker can retry.
  """
  def deliver(event_type, payload) do
    case webhook_url() do
      nil ->
        :ok

      url ->
        post(url, event_type, payload)
    end
  end

  defp post(url, event_type, payload) do
    body = %{event: event_type, data: payload, timestamp: DateTime.utc_now()}

    case Req.post(url, json: body, receive_timeout: 10_000) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.warning("Webhook notification returned #{status}: #{inspect(resp_body)}")
        {:error, "webhook returned #{status}"}

      {:error, reason} ->
        Logger.warning("Webhook notification failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp webhook_url do
    Application.get_env(:experiment_hub, :alert_webhook_url)
  end
end
