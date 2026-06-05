defmodule ExperimentHubWeb.EventController do
  use ExperimentHubWeb, :controller

  alias EventCollector.Validation.{EventValidator, BotDetector}
  alias EventCollector.Kafka.Producer

  action_fallback ExperimentHubWeb.FallbackController

  @max_batch_size 1000

  @doc """
  POST /v1/events - Single event submission
  """
  def create(conn, params) do
    tenant_id = conn.assigns.tenant_id
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    event =
      params
      |> Map.put("tenant_id", tenant_id)
      |> BotDetector.tag_event(user_agent)

    case EventValidator.validate(event) do
      {:ok, validated} ->
        Producer.produce_event(validated)

        conn
        |> put_status(202)
        |> json(%{
          status: "accepted",
          event_id: Ecto.UUID.generate(),
          received_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, errors} ->
        conn
        |> put_status(400)
        |> json(%{
          error: "validation_error",
          message: format_first_error(errors),
          details: errors
        })
    end
  end

  @doc """
  POST /v1/events/batch - Batch event submission (max 1000)
  """
  def batch_create(conn, %{"events" => events}) when is_list(events) do
    tenant_id = conn.assigns.tenant_id
    user_agent = get_req_header(conn, "user-agent") |> List.first()

    events = Enum.take(events, @max_batch_size)

    tagged_events =
      Enum.map(events, fn event ->
        event
        |> Map.put("tenant_id", tenant_id)
        |> BotDetector.tag_event(user_agent)
      end)

    {accepted, rejected} = EventValidator.validate_batch(tagged_events)

    # Produce accepted events to Kafka
    if length(accepted) > 0 do
      Producer.produce_batch(accepted)
    end

    status_code =
      cond do
        length(rejected) == 0 -> 202
        length(accepted) == 0 -> 400
        true -> 207
      end

    status_label =
      cond do
        length(rejected) == 0 -> "accepted"
        length(accepted) == 0 -> "rejected"
        true -> "partial"
      end

    conn
    |> put_status(status_code)
    |> json(%{
      status: status_label,
      accepted: length(accepted),
      rejected: length(rejected),
      errors: format_batch_errors(rejected),
      received_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  def batch_create(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{
      error: "validation_error",
      message: "Missing required field: events",
      details: [%{field: "events", error: "is required and must be an array"}]
    })
  end

  defp format_first_error([%{field: field, error: error} | _]) do
    "#{String.capitalize(String.replace(error, "_", " "))}: #{field}"
  end

  defp format_first_error(_), do: "Validation error"

  defp format_batch_errors(rejected) do
    Enum.map(rejected, fn %{index: index, error: error, details: details} ->
      %{
        index: index,
        error: error,
        message: format_error_message(details),
        details: details
      }
    end)
  end

  defp format_error_message([%{field: field, error: error} | _]) do
    "#{String.capitalize(error)}: #{field}"
  end

  defp format_error_message(_), do: "Validation error"
end
