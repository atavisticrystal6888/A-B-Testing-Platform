defmodule ExperimentHub.TargetingTest do
  use ExperimentHub.DataCase, async: true

  alias ExperimentHub.Targeting

  describe "evaluate/2" do
    test "returns true when no rules" do
      assert Targeting.evaluate(nil, %{}) == true
      assert Targeting.evaluate([], %{}) == true
    end

    test "evaluates eq operator" do
      rules = [%{"attribute" => "country", "operator" => "eq", "value" => "US"}]
      assert Targeting.evaluate(rules, %{"country" => "US"}) == true
      assert Targeting.evaluate(rules, %{"country" => "UK"}) == false
    end

    test "evaluates neq operator" do
      rules = [%{"attribute" => "country", "operator" => "neq", "value" => "US"}]
      assert Targeting.evaluate(rules, %{"country" => "UK"}) == true
      assert Targeting.evaluate(rules, %{"country" => "US"}) == false
    end

    test "evaluates in operator" do
      rules = [%{"attribute" => "country", "operator" => "in", "value" => ["US", "UK", "CA"]}]
      assert Targeting.evaluate(rules, %{"country" => "US"}) == true
      assert Targeting.evaluate(rules, %{"country" => "DE"}) == false
    end

    test "evaluates not_in operator" do
      rules = [%{"attribute" => "country", "operator" => "not_in", "value" => ["US", "UK"]}]
      assert Targeting.evaluate(rules, %{"country" => "DE"}) == true
      assert Targeting.evaluate(rules, %{"country" => "US"}) == false
    end

    test "evaluates numeric comparisons" do
      rules = [%{"attribute" => "age", "operator" => "gte", "value" => 18}]
      assert Targeting.evaluate(rules, %{"age" => 21}) == true
      assert Targeting.evaluate(rules, %{"age" => 17}) == false
    end

    test "evaluates contains operator" do
      rules = [%{"attribute" => "email", "operator" => "contains", "value" => "@example.com"}]
      assert Targeting.evaluate(rules, %{"email" => "user@example.com"}) == true
      assert Targeting.evaluate(rules, %{"email" => "user@other.com"}) == false
    end

    test "evaluates nested attributes" do
      rules = [%{"attribute" => "device.os", "operator" => "eq", "value" => "ios"}]
      assert Targeting.evaluate(rules, %{"device" => %{"os" => "ios"}}) == true
    end

    test "evaluates OR conditions" do
      rules = [
        %{
          "or" => [
            %{"attribute" => "country", "operator" => "eq", "value" => "US"},
            %{"attribute" => "country", "operator" => "eq", "value" => "UK"}
          ]
        }
      ]

      assert Targeting.evaluate(rules, %{"country" => "US"}) == true
      assert Targeting.evaluate(rules, %{"country" => "UK"}) == true
      assert Targeting.evaluate(rules, %{"country" => "DE"}) == false
    end

    test "evaluates AND conditions (implicit)" do
      rules = [
        %{"attribute" => "country", "operator" => "eq", "value" => "US"},
        %{"attribute" => "age", "operator" => "gte", "value" => 18}
      ]

      assert Targeting.evaluate(rules, %{"country" => "US", "age" => 21}) == true
      assert Targeting.evaluate(rules, %{"country" => "US", "age" => 16}) == false
    end

    test "evaluates NOT conditions" do
      rules = [%{"not" => %{"attribute" => "country", "operator" => "eq", "value" => "US"}}]
      assert Targeting.evaluate(rules, %{"country" => "UK"}) == true
      assert Targeting.evaluate(rules, %{"country" => "US"}) == false
    end

    test "evaluates matches (regex) operator" do
      rules = [%{"attribute" => "email", "operator" => "matches", "value" => "^admin@"}]
      assert Targeting.evaluate(rules, %{"email" => "admin@example.com"}) == true
      assert Targeting.evaluate(rules, %{"email" => "user@example.com"}) == false
    end

    test "returns false for missing attributes" do
      rules = [%{"attribute" => "country", "operator" => "eq", "value" => "US"}]
      assert Targeting.evaluate(rules, %{}) == false
    end
  end

  describe "validate_rules/1" do
    test "validates valid rules" do
      rules = [%{"attribute" => "country", "operator" => "eq", "value" => "US"}]
      assert Targeting.validate_rules(rules) == :ok
    end

    test "rejects invalid operator" do
      rules = [%{"attribute" => "country", "operator" => "invalid", "value" => "US"}]
      assert {:error, _} = Targeting.validate_rules(rules)
    end

    test "validates nil rules" do
      assert Targeting.validate_rules(nil) == :ok
    end
  end
end
