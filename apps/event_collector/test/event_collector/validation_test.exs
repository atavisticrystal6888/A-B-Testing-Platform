defmodule EventCollector.Validation.EventValidatorTest do
  use ExUnit.Case, async: true

  alias EventCollector.Validation.EventValidator

  @valid_event %{
    "experiment_id" => "550e8400-e29b-41d4-a716-446655440000",
    "user_id" => "user-1",
    "event_type" => "conversion",
    "event_name" => "checkout_completed",
    "value" => 1,
    "timestamp" => "2026-04-01T12:00:00Z",
    "idempotency_key" => "evt_001"
  }

  describe "validate/1" do
    test "accepts valid conversion event" do
      assert {:ok, _} = EventValidator.validate(@valid_event)
    end

    test "accepts valid metric event with value" do
      event = Map.merge(@valid_event, %{"event_type" => "metric", "value" => 1.5})
      assert {:ok, _} = EventValidator.validate(event)
    end

    test "accepts valid revenue event with value" do
      event = Map.merge(@valid_event, %{"event_type" => "revenue", "value" => 49.99})
      assert {:ok, _} = EventValidator.validate(event)
    end

    test "rejects event missing experiment_id" do
      event = Map.delete(@valid_event, "experiment_id")
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "experiment_id"))
    end

    test "rejects event missing user_id" do
      event = Map.delete(@valid_event, "user_id")
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "user_id"))
    end

    test "rejects invalid event_type" do
      event = Map.put(@valid_event, "event_type", "invalid")
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "event_type"))
    end

    test "rejects metric event without value" do
      event = @valid_event |> Map.put("event_type", "metric") |> Map.delete("value")
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "value"))
    end

    test "rejects invalid UUID for experiment_id" do
      event = Map.put(@valid_event, "experiment_id", "not-a-uuid")
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "experiment_id"))
    end

    test "rejects invalid timestamp" do
      event = Map.put(@valid_event, "timestamp", "not-a-timestamp")
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "timestamp"))
    end

    test "rejects user_id exceeding max length" do
      event = Map.put(@valid_event, "user_id", String.duplicate("x", 256))
      assert {:error, errors} = EventValidator.validate(event)
      assert Enum.any?(errors, &(&1.field == "user_id"))
    end
  end

  describe "validate_batch/1" do
    test "separates valid and invalid events" do
      events = [
        @valid_event,
        Map.delete(@valid_event, "user_id"),
        Map.put(@valid_event, "idempotency_key", "evt_002")
      ]

      {accepted, rejected} = EventValidator.validate_batch(events)
      assert length(accepted) == 2
      assert length(rejected) == 1
    end

    test "returns index of rejected events" do
      events = [
        @valid_event,
        %{},
        Map.put(@valid_event, "idempotency_key", "evt_003")
      ]

      {_accepted, rejected} = EventValidator.validate_batch(events)
      assert [%{index: 1} | _] = rejected
    end
  end
end
