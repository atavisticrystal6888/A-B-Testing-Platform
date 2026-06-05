defmodule ExperimentHub.Experiments.StateMachineTest do
  use ExUnit.Case, async: true

  alias ExperimentHub.Experiments.StateMachine

  describe "valid_transition?/2" do
    test "draft → running is valid" do
      assert StateMachine.valid_transition?("draft", "running")
    end

    test "running → paused is valid" do
      assert StateMachine.valid_transition?("running", "paused")
    end

    test "running → concluded is valid" do
      assert StateMachine.valid_transition?("running", "concluded")
    end

    test "paused → running is valid" do
      assert StateMachine.valid_transition?("paused", "running")
    end

    test "paused → concluded is valid" do
      assert StateMachine.valid_transition?("paused", "concluded")
    end

    test "draft → paused is invalid" do
      refute StateMachine.valid_transition?("draft", "paused")
    end

    test "draft → concluded is invalid" do
      refute StateMachine.valid_transition?("draft", "concluded")
    end

    test "concluded → running is invalid" do
      refute StateMachine.valid_transition?("concluded", "running")
    end

    test "concluded → draft is invalid" do
      refute StateMachine.valid_transition?("concluded", "draft")
    end

    test "concluded → paused is invalid" do
      refute StateMachine.valid_transition?("concluded", "paused")
    end

    test "running → draft is invalid" do
      refute StateMachine.valid_transition?("running", "draft")
    end
  end

  describe "validate_transition/2" do
    test "returns :ok for valid transitions" do
      assert :ok = StateMachine.validate_transition("draft", "running")
      assert :ok = StateMachine.validate_transition("running", "paused")
      assert :ok = StateMachine.validate_transition("paused", "concluded")
    end

    test "returns error for invalid transitions" do
      assert {:error, message} = StateMachine.validate_transition("concluded", "running")
      assert message =~ "Invalid transition"
      assert message =~ "concluded"
      assert message =~ "running"
    end
  end

  describe "valid_next_states/1" do
    test "draft can go to running" do
      assert StateMachine.valid_next_states("draft") == ["running"]
    end

    test "running can go to paused or concluded" do
      assert StateMachine.valid_next_states("running") == ["paused", "concluded"]
    end

    test "paused can go to running or concluded" do
      assert StateMachine.valid_next_states("paused") == ["running", "concluded"]
    end

    test "concluded has no next states" do
      assert StateMachine.valid_next_states("concluded") == []
    end
  end
end
