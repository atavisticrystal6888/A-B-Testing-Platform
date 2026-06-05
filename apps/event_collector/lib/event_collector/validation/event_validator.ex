defmodule EventCollector.Validation.EventValidator do
  @moduledoc """
  Validates inbound experiment events against the event-api.md contract.
  """

  @valid_event_types ~w(conversion metric revenue)
  @max_user_id_length 255
  @max_event_name_length 100
  @max_idempotency_key_length 255

  @doc """
  Validate a single event. Returns `{:ok, validated_event}` or `{:error, errors}`.
  """
  def validate(event) when is_map(event) do
    errors = []

    errors = validate_required(event, "experiment_id", errors)
    errors = validate_required(event, "user_id", errors)
    errors = validate_required(event, "event_type", errors)
    errors = validate_required(event, "event_name", errors)
    errors = validate_required(event, "timestamp", errors)
    errors = validate_required(event, "idempotency_key", errors)

    errors = validate_event_type(event, errors)
    errors = validate_uuid(event, "experiment_id", errors)
    errors = validate_length(event, "user_id", @max_user_id_length, errors)
    errors = validate_length(event, "event_name", @max_event_name_length, errors)
    errors = validate_length(event, "idempotency_key", @max_idempotency_key_length, errors)
    errors = validate_value_required(event, errors)
    errors = validate_timestamp(event, errors)

    case errors do
      [] ->
        validated =
          event
          |> maybe_tag_post_conclusion()
          |> maybe_tag_bot()

        {:ok, validated}

      errors ->
        {:error, Enum.reverse(errors)}
    end
  end

  def validate(_), do: {:error, [%{field: "event", error: "must be a map"}]}

  @doc """
  Validate a batch of events. Returns `{accepted, rejected}` lists.
  """
  def validate_batch(events) when is_list(events) do
    events
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {event, index}, {accepted, rejected} ->
      case validate(event) do
        {:ok, validated} ->
          {[validated | accepted], rejected}

        {:error, errors} ->
          error = %{index: index, error: "validation_error", details: errors}
          {accepted, [error | rejected]}
      end
    end)
    |> then(fn {accepted, rejected} ->
      {Enum.reverse(accepted), Enum.reverse(rejected)}
    end)
  end

  defp validate_required(event, field, errors) do
    if Map.has_key?(event, field) && event[field] != nil && event[field] != "" do
      errors
    else
      [%{field: field, error: "is required"} | errors]
    end
  end

  defp validate_event_type(event, errors) do
    case event["event_type"] do
      nil ->
        errors

      type when type in @valid_event_types ->
        errors

      _ ->
        [
          %{field: "event_type", error: "must be one of: #{Enum.join(@valid_event_types, ", ")}"}
          | errors
        ]
    end
  end

  defp validate_uuid(event, field, errors) do
    case event[field] do
      nil ->
        errors

      value ->
        case Ecto.UUID.cast(value) do
          {:ok, _} -> errors
          :error -> [%{field: field, error: "must be a valid UUID"} | errors]
        end
    end
  end

  defp validate_length(event, field, max, errors) do
    case event[field] do
      nil ->
        errors

      value when is_binary(value) ->
        if String.length(value) > max do
          [%{field: field, error: "must be at most #{max} characters"} | errors]
        else
          errors
        end

      _ ->
        errors
    end
  end

  defp validate_value_required(event, errors) do
    case event["event_type"] do
      type when type in ["metric", "revenue"] ->
        if event["value"] == nil do
          [%{field: "value", error: "is required for #{type} events"} | errors]
        else
          errors
        end

      _ ->
        errors
    end
  end

  defp validate_timestamp(event, errors) do
    case event["timestamp"] do
      nil ->
        errors

      ts when is_binary(ts) ->
        case DateTime.from_iso8601(ts) do
          {:ok, _, _} -> errors
          _ -> [%{field: "timestamp", error: "must be a valid ISO 8601 timestamp"} | errors]
        end

      _ ->
        [%{field: "timestamp", error: "must be a valid ISO 8601 timestamp"} | errors]
    end
  end

  defp maybe_tag_post_conclusion(event) do
    # Post-conclusion tagging is done at persistence time by checking experiment status
    Map.put_new(event, "is_post_conclusion", false)
  end

  defp maybe_tag_bot(event) do
    Map.put_new(event, "is_bot", false)
  end
end
