"""Contract tests for the Statistical Engine API endpoints."""
from fastapi.testclient import TestClient

from src.api.main import app

client = TestClient(app)

INTERNAL_KEY_HEADER = {"x-internal-key": "dev-internal-key"}


class TestHealthEndpoint:
    def test_health_returns_ok(self):
        response = client.get("/stats/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert data["service"] == "statistical-engine"


class TestAnalyzeEndpoint:
    def test_analyze_returns_200(self):
        payload = {
            "tenant_id": "110e8400-e29b-41d4-a716-446655440000",
            "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
            "metrics": [
                {
                    "metric_definition_id": "990e8400-e29b-41d4-a716-446655440020",
                    "metric_key": "checkout_conversion",
                    "metric_type": "count",
                    "role": "primary",
                }
            ],
            "variants": [
                {"variant_id": "660e8400-0000-0000-0000-000000000001", "variant_key": "control", "is_control": True},
                {"variant_id": "660e8400-0000-0000-0000-000000000002", "variant_key": "treatment", "is_control": False},
            ],
            "config": {
                "significance_level": 0.05,
                "power": 0.80,
                "analysis_types": ["frequentist"],
            },
        }

        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=payload,
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["experiment_id"] == "550e8400-e29b-41d4-a716-446655440000"
        assert "computed_at" in data
        assert "computation_time_ms" in data
        assert "metrics" in data
        assert "overall_status" in data

        metric = data["metrics"][0]
        assert metric["metric_key"] == "checkout_conversion"
        assert metric["role"] == "primary"
        assert "frequentist" in metric
        assert "recommendation" in metric

    def test_analyze_with_guardrail(self):
        payload = {
            "tenant_id": "110e8400-e29b-41d4-a716-446655440000",
            "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
            "metrics": [
                {
                    "metric_definition_id": "990e8400-e29b-41d4-a716-446655440021",
                    "metric_key": "error_rate",
                    "metric_type": "count",
                    "role": "guardrail",
                    "guardrail_threshold": 0.05,
                    "guardrail_direction": "above",
                }
            ],
            "variants": [
                {"variant_id": "660e8400-0000-0000-0000-000000000001", "variant_key": "control", "is_control": True},
                {"variant_id": "660e8400-0000-0000-0000-000000000002", "variant_key": "treatment", "is_control": False},
            ],
        }

        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=payload,
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        data = response.json()
        metric = data["metrics"][0]
        assert "guardrail_status" in metric

    def test_analyze_requires_auth(self):
        response = client.post(
            "/stats/v1/analyze/test-id",
            json={"tenant_id": "t", "experiment_id": "e", "metrics": [], "variants": []},
        )
        assert response.status_code == 401

    def test_get_cached_results(self):
        # First run analysis
        payload = {
            "tenant_id": "110e8400-e29b-41d4-a716-446655440000",
            "experiment_id": "cache-test-exp",
            "metrics": [
                {
                    "metric_definition_id": "990e8400-e29b-41d4-a716-446655440020",
                    "metric_key": "test_metric",
                    "metric_type": "count",
                    "role": "primary",
                }
            ],
            "variants": [
                {"variant_id": "660e8400-0000-0000-0000-000000000001", "variant_key": "control", "is_control": True},
                {"variant_id": "660e8400-0000-0000-0000-000000000002", "variant_key": "treatment", "is_control": False},
            ],
        }

        client.post("/stats/v1/analyze/cache-test-exp", json=payload, headers=INTERNAL_KEY_HEADER)

        # Then get cached results
        response = client.get("/stats/v1/analyze/cache-test-exp/results", headers=INTERNAL_KEY_HEADER)
        assert response.status_code == 200


class TestPowerEndpoint:
    def test_power_calculation(self):
        payload = {
            "baseline_rate": 0.10,
            "minimum_detectable_effect": 0.02,
            "significance_level": 0.05,
            "power": 0.80,
            "num_variants": 2,
        }

        response = client.post("/stats/v1/power", json=payload, headers=INTERNAL_KEY_HEADER)
        assert response.status_code == 200
        data = response.json()

        assert "sample_size_per_variant" in data
        assert "total_sample_size" in data
        assert data["total_sample_size"] == data["sample_size_per_variant"] * 2

    def test_power_validation(self):
        payload = {
            "baseline_rate": 0.0,  # Invalid
            "minimum_detectable_effect": 0.02,
        }

        response = client.post("/stats/v1/power", json=payload, headers=INTERNAL_KEY_HEADER)
        assert response.status_code == 422


class TestReproducibility:
    """Test FR-030: reproducible analysis results."""

    def test_identical_analysis_produces_identical_results(self):
        payload = {
            "tenant_id": "110e8400-e29b-41d4-a716-446655440000",
            "experiment_id": "repro-test-exp",
            "metrics": [
                {
                    "metric_definition_id": "990e8400-e29b-41d4-a716-446655440020",
                    "metric_key": "repro_metric",
                    "metric_type": "count",
                    "role": "primary",
                }
            ],
            "variants": [
                {"variant_id": "660e8400-0000-0000-0000-000000000001", "variant_key": "control", "is_control": True},
                {"variant_id": "660e8400-0000-0000-0000-000000000002", "variant_key": "treatment", "is_control": False},
            ],
            "config": {"significance_level": 0.05, "power": 0.80},
        }

        r1 = client.post("/stats/v1/analyze/repro-test-exp", json=payload, headers=INTERNAL_KEY_HEADER)
        r2 = client.post("/stats/v1/analyze/repro-test-exp", json=payload, headers=INTERNAL_KEY_HEADER)

        d1 = r1.json()
        d2 = r2.json()

        m1 = d1["metrics"][0]["frequentist"]
        m2 = d2["metrics"][0]["frequentist"]

        assert abs(m1["p_value"] - m2["p_value"]) / max(m1["p_value"], 1e-10) < 0.001
