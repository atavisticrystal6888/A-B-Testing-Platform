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


def _payload(metrics, experiment_id="550e8400-e29b-41d4-a716-446655440000", config=None):
    return {
        "tenant_id": "110e8400-e29b-41d4-a716-446655440000",
        "experiment_id": experiment_id,
        "metrics": metrics,
        "variants": [
            {"variant_id": "660e8400-0000-0000-0000-000000000001", "variant_key": "control", "is_control": True},
            {"variant_id": "660e8400-0000-0000-0000-000000000002", "variant_key": "treatment", "is_control": False},
        ],
        "config": config or {"significance_level": 0.05, "power": 0.80, "analysis_types": ["frequentist"]},
    }


def _primary_metric(variant_stats=None, metric_type="count"):
    metric = {
        "metric_definition_id": "990e8400-e29b-41d4-a716-446655440020",
        "metric_key": "checkout_conversion",
        "metric_type": metric_type,
        "role": "primary",
    }
    if variant_stats is not None:
        metric["variant_stats"] = variant_stats
    return metric


class TestAnalyzeEndpoint:
    def test_analyze_computes_from_provided_counts(self):
        # 5000/arm clears the required sample size at baseline 10% / MDE 2pp,
        # and 10% vs 15% is decisively significant.
        stats = [
            {"variant_key": "control", "sample_size": 5000, "conversions": 500},
            {"variant_key": "treatment", "sample_size": 5000, "conversions": 750},
        ]

        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=_payload([_primary_metric(stats)]),
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        data = response.json()

        assert data["experiment_id"] == "550e8400-e29b-41d4-a716-446655440000"
        assert "computed_at" in data
        assert "overall_status" in data

        metric = data["metrics"][0]
        assert metric["metric_key"] == "checkout_conversion"
        assert metric["role"] == "primary"

        # The response must reflect the provided counts, not placeholders.
        by_key = {v["variant_key"]: v for v in metric["variants"]}
        assert by_key["control"]["sample_size"] == 5000
        assert by_key["control"]["conversions"] == 500
        assert abs(by_key["control"]["conversion_rate"] - 0.10) < 1e-9
        assert abs(by_key["treatment"]["conversion_rate"] - 0.15) < 1e-9

        freq = metric["frequentist"]
        assert freq["is_significant"] is True
        assert abs(freq["effect_size"]["absolute"] - 0.05) < 1e-9
        assert abs(freq["effect_size"]["relative"] - 0.5) < 1e-9
        assert metric["recommendation"]["action"] == "significant_winner"
        assert metric["recommendation"]["winning_variant"] == "treatment"

    def test_analyze_without_stats_reports_insufficient_data(self):
        # No variant_stats provided: the engine must NOT invent numbers.
        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=_payload([_primary_metric()]),
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        metric = response.json()["metrics"][0]

        assert metric["recommendation"]["action"] == "insufficient_data"
        assert metric["frequentist"] is None
        assert all(v["sample_size"] == 0 for v in metric["variants"])

    def test_analyze_unsupported_metric_type_fails_visibly(self):
        # ratio/funnel have no implemented test; they must surface as
        # insufficient_data, not fall through to the proportion z-test.
        stats = [
            {"variant_key": "control", "sample_size": 5000, "conversions": 500},
            {"variant_key": "treatment", "sample_size": 5000, "conversions": 750},
        ]

        for metric_type in ("ratio", "funnel"):
            response = client.post(
                "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
                json=_payload([_primary_metric(stats, metric_type=metric_type)]),
                headers=INTERNAL_KEY_HEADER,
            )
            assert response.status_code == 200
            metric = response.json()["metrics"][0]
            assert metric["recommendation"]["action"] == "insufficient_data"
            assert "not yet supported" in metric["recommendation"]["message"]
            assert metric["frequentist"] is None

    def test_analyze_sum_metric_uses_welch(self):
        # Revenue-style metric: mean over assigned users, non-buyers at 0.
        stats = [
            {"variant_key": "control", "sample_size": 2000, "conversions": 200,
             "sum_value": 16000.0, "sum_squared_value": 1400000.0},
            {"variant_key": "treatment", "sample_size": 2000, "conversions": 260,
             "sum_value": 23400.0, "sum_squared_value": 2300000.0},
        ]

        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=_payload([_primary_metric(stats, metric_type="sum")]),
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        metric = response.json()["metrics"][0]

        assert metric["frequentist"]["test_method"] == "welchs_t_test"
        by_key = {v["variant_key"]: v for v in metric["variants"]}
        assert abs(by_key["control"]["mean"] - 8.0) < 1e-9
        assert abs(by_key["treatment"]["mean"] - 11.7) < 1e-9

    def test_analyze_with_guardrail_breach(self):
        # Error rate quadruples (1% -> 4%): relative effect 3.0 > 0.5 threshold.
        payload = _payload([
            {
                "metric_definition_id": "990e8400-e29b-41d4-a716-446655440021",
                "metric_key": "error_rate",
                "metric_type": "count",
                "role": "guardrail",
                "guardrail_threshold": 0.5,
                "guardrail_direction": "above",
                "variant_stats": [
                    {"variant_key": "control", "sample_size": 5000, "conversions": 50},
                    {"variant_key": "treatment", "sample_size": 5000, "conversions": 200},
                ],
            }
        ])

        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=payload,
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        data = response.json()
        metric = data["metrics"][0]

        status = metric["guardrail_status"]
        assert status["is_breached"] is True
        assert abs(status["current_value"] - 3.0) < 1e-6
        # Elixir's GuardrailEvaluator reads this path — it must be present.
        assert abs(metric["frequentist"]["effect_size"]["relative"] - 3.0) < 1e-6
        assert data["overall_status"] == "guardrail_breach"

    def test_analyze_guardrail_without_data_does_not_breach(self):
        payload = _payload([
            {
                "metric_definition_id": "990e8400-e29b-41d4-a716-446655440021",
                "metric_key": "error_rate",
                "metric_type": "count",
                "role": "guardrail",
                "guardrail_threshold": 0.05,
                "guardrail_direction": "above",
            }
        ])

        response = client.post(
            "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
            json=payload,
            headers=INTERNAL_KEY_HEADER,
        )
        assert response.status_code == 200
        metric = response.json()["metrics"][0]
        assert metric["guardrail_status"]["is_breached"] is False

    def test_guardrail_unsupported_metric_type_never_breaches(self):
        # A ratio/funnel guardrail must not fall through to the z-test: a
        # false breach computed on the wrong variance model would gate a
        # rollout. 1% -> 4% would decisively breach if the test ran.
        for metric_type in ("ratio", "funnel"):
            payload = _payload([
                {
                    "metric_definition_id": "990e8400-e29b-41d4-a716-446655440021",
                    "metric_key": "error_rate",
                    "metric_type": metric_type,
                    "role": "guardrail",
                    "guardrail_threshold": 0.5,
                    "guardrail_direction": "above",
                    "variant_stats": [
                        {"variant_key": "control", "sample_size": 5000, "conversions": 50},
                        {"variant_key": "treatment", "sample_size": 5000, "conversions": 200},
                    ],
                }
            ])

            response = client.post(
                "/stats/v1/analyze/550e8400-e29b-41d4-a716-446655440000",
                json=payload,
                headers=INTERNAL_KEY_HEADER,
            )
            assert response.status_code == 200
            data = response.json()
            metric = data["metrics"][0]
            assert metric["frequentist"] is None
            assert metric["guardrail_status"]["is_breached"] is False
            assert "not yet supported" in metric["recommendation"]["message"]
            assert data["overall_status"] != "guardrail_breach"

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
        stats = [
            {"variant_key": "control", "sample_size": 5000, "conversions": 500},
            {"variant_key": "treatment", "sample_size": 5000, "conversions": 600},
        ]
        payload = _payload([_primary_metric(stats)], experiment_id="repro-test-exp")

        r1 = client.post("/stats/v1/analyze/repro-test-exp", json=payload, headers=INTERNAL_KEY_HEADER)
        r2 = client.post("/stats/v1/analyze/repro-test-exp", json=payload, headers=INTERNAL_KEY_HEADER)

        d1 = r1.json()
        d2 = r2.json()

        m1 = d1["metrics"][0]["frequentist"]
        m2 = d2["metrics"][0]["frequentist"]

        assert abs(m1["p_value"] - m2["p_value"]) / max(m1["p_value"], 1e-10) < 0.001
