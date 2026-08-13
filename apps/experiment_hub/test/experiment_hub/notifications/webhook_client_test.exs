defmodule ExperimentHub.Notifications.WebhookClientTest do
  use ExUnit.Case, async: false

  alias ExperimentHub.Notifications.WebhookClient

  setup do
    original = Application.get_env(:experiment_hub, :alert_webhook_url)
    on_exit(fn -> Application.put_env(:experiment_hub, :alert_webhook_url, original) end)
  end

  test "no-ops when no webhook URL is configured" do
    Application.delete_env(:experiment_hub, :alert_webhook_url)

    assert :ok = WebhookClient.deliver("analysis.significant", %{"experiment_id" => "123"})
  end

  test "reports a connection failure as an error so Oban can retry" do
    # Nothing listens on this port — the POST must fail to connect.
    Application.put_env(:experiment_hub, :alert_webhook_url, "http://127.0.0.1:1/webhook")

    assert {:error, _reason} =
             WebhookClient.deliver("analysis.significant", %{"experiment_id" => "123"})
  end
end
