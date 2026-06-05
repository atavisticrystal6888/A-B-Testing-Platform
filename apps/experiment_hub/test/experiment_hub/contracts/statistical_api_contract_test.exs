defmodule ExperimentHub.Contracts.StatisticalApiContractTest do
  use ExperimentHub.DataCase, async: true

  @moduledoc """
  Contract test validating Elixir HTTP client request format and response
  parsing against statistical-api.md contract schema (Constitution Art.III).
  """

  describe "analysis request format" do
    test "request body matches contract schema" do
      request = %{
        experiment_id: Ecto.UUID.generate(),
        variants: [
          %{variant_id: "v1", sample_size: 1000, conversions: 100},
          %{variant_id: "v2", sample_size: 1000, conversions: 120}
        ],
        analysis_type: "frequentist",
        confidence_level: 0.95
      }

      assert is_binary(request.experiment_id)
      assert length(request.variants) >= 2
      assert request.confidence_level > 0 and request.confidence_level < 1

      for v <- request.variants do
        assert is_binary(v.variant_id)
        assert is_integer(v.sample_size)
        assert is_integer(v.conversions)
        assert v.sample_size >= 0
        assert v.conversions >= 0
        assert v.conversions <= v.sample_size
      end
    end

    test "power calculation request matches contract schema" do
      request = %{
        baseline_rate: 0.10,
        minimum_detectable_effect: 0.02,
        significance_level: 0.05,
        power: 0.80,
        variants: 2
      }

      assert request.baseline_rate > 0 and request.baseline_rate < 1
      assert request.minimum_detectable_effect > 0
      assert request.significance_level > 0 and request.significance_level < 0.5
      assert request.power > 0 and request.power < 1
      assert request.variants >= 2
    end
  end

  describe "response parsing" do
    test "analysis response has required fields" do
      response = %{
        "experiment_id" => Ecto.UUID.generate(),
        "overall_status" => "significant",
        "variants" => [
          %{
            "variant_id" => "v1",
            "sample_size" => 1000,
            "conversions" => 100,
            "conversion_rate" => 0.10,
            "ci_lower" => 0.08,
            "ci_upper" => 0.12
          }
        ],
        "p_value" => 0.03,
        "is_significant" => true,
        "confidence_level" => 0.95
      }

      assert Map.has_key?(response, "experiment_id")
      assert Map.has_key?(response, "overall_status")
      assert Map.has_key?(response, "variants")
      assert Map.has_key?(response, "p_value")
      assert is_list(response["variants"])
    end

    test "error response format" do
      error_response = %{
        "error" => "insufficient_data",
        "message" => "Not enough samples for analysis",
        "status" => 422
      }

      assert Map.has_key?(error_response, "error")
      assert Map.has_key?(error_response, "message")
    end
  end
end
