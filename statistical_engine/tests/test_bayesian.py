"""Tests for Bayesian analysis module (FR-105)."""

from src.core.bayesian import beta_binomial_analysis, normal_analysis


class TestBetaBinomialAnalysis:
    def test_clear_winner(self):
        result = beta_binomial_analysis(
            control_successes=100,
            control_trials=1000,
            treatment_successes=150,
            treatment_trials=1000,
        )

        assert result["treatment"].probability_best > 0.95
        assert result["difference"]["prob_positive"] > 0.95
        assert result["difference"]["mean"] > 0

    def test_no_difference(self):
        result = beta_binomial_analysis(
            control_successes=100,
            control_trials=1000,
            treatment_successes=100,
            treatment_trials=1000,
        )

        assert 0.3 < result["treatment"].probability_best < 0.7
        assert abs(result["difference"]["mean"]) < 0.02

    def test_rope(self):
        result = beta_binomial_analysis(
            control_successes=100,
            control_trials=1000,
            treatment_successes=101,
            treatment_trials=1000,
            rope=0.01,
        )

        assert result["difference"]["rope_probability"] > 0.5

    def test_credible_interval(self):
        result = beta_binomial_analysis(
            control_successes=500,
            control_trials=5000,
            treatment_successes=550,
            treatment_trials=5000,
        )

        ci = result["treatment"].credible_interval
        assert ci[0] < ci[1]
        assert ci[0] > 0
        assert ci[1] < 1

    def test_deterministic(self):
        r1 = beta_binomial_analysis(
            control_successes=100, control_trials=1000,
            treatment_successes=120, treatment_trials=1000,
        )
        r2 = beta_binomial_analysis(
            control_successes=100, control_trials=1000,
            treatment_successes=120, treatment_trials=1000,
        )
        assert r1["treatment"].probability_best == r2["treatment"].probability_best


class TestNormalAnalysis:
    def test_significant_difference(self):
        result = normal_analysis(
            control_mean=10.0, control_std=2.0, control_n=1000,
            treatment_mean=11.0, treatment_std=2.0, treatment_n=1000,
        )

        assert result["probability_best"] > 0.95
        assert result["difference"]["mean"] > 0.8

    def test_no_difference(self):
        result = normal_analysis(
            control_mean=10.0, control_std=2.0, control_n=100,
            treatment_mean=10.1, treatment_std=2.0, treatment_n=100,
        )

        assert 0.3 < result["probability_best"] < 0.9
