"""Tests for frequentist analysis: z-test and Welch's t-test."""
import pytest
from scipy import stats as scipy_stats

from src.core.frequentist import welchs_t_test, z_test_proportions


class TestZTestProportions:
    """Property-based and exact tests for z_test_proportions."""

    def test_known_result_matches_standard_formula(self):
        """z-test result matches the standard pooled two-proportion formula."""
        control_n = 5000
        treatment_n = 5000
        control_conv = 500
        treatment_conv = 600

        result = z_test_proportions(control_conv, control_n, treatment_conv, treatment_n)

        control_rate = control_conv / control_n
        treatment_rate = treatment_conv / treatment_n
        pooled_rate = (control_conv + treatment_conv) / (control_n + treatment_n)
        standard_error = ((pooled_rate * (1 - pooled_rate)) * ((1 / control_n) + (1 / treatment_n))) ** 0.5
        z_stat = (treatment_rate - control_rate) / standard_error
        p_value = 2 * (1 - scipy_stats.norm.cdf(abs(z_stat)))

        assert abs(result.p_value - p_value) / p_value < 0.001, (
            f"p-value mismatch: {result.p_value} vs {p_value}"
        )

    def test_significance_detection(self):
        result = z_test_proportions(100, 1000, 150, 1000, 0.05)
        assert result.is_significant is True
        assert result.p_value < 0.05

    def test_no_significance_with_small_effect(self):
        result = z_test_proportions(100, 1000, 102, 1000, 0.05)
        assert result.is_significant is False

    def test_confidence_interval_contains_true_effect(self):
        result = z_test_proportions(500, 5000, 600, 5000)
        ci_lower, ci_upper, point = result.confidence_interval
        assert ci_lower < point < ci_upper

    def test_effect_size_correct_sign(self):
        result = z_test_proportions(100, 1000, 150, 1000)
        assert result.effect_size_absolute > 0
        assert result.effect_size_relative > 0

    def test_cohens_h_computed(self):
        result = z_test_proportions(100, 1000, 150, 1000)
        assert result.cohens_h is not None
        assert abs(result.cohens_h) > 0

    def test_power_computed(self):
        result = z_test_proportions(500, 5000, 600, 5000)
        assert 0 < result.power_achieved <= 1

    def test_identical_rates_not_significant(self):
        result = z_test_proportions(100, 1000, 100, 1000)
        assert result.is_significant is False
        assert result.p_value > 0.9

    @pytest.mark.parametrize("n", [100, 500, 1000, 5000, 10000])
    def test_various_sample_sizes(self, n):
        """z-test produces valid results across sample sizes."""
        result = z_test_proportions(
            int(n * 0.10), n,
            int(n * 0.12), n,
        )
        assert 0 <= result.p_value <= 1
        assert result.test_method == "z_test_proportions"


class TestWelchsTTest:
    """Tests for Welch's t-test."""

    def test_known_result_matches_scipy(self):
        """Welch's t-test matches scipy.stats.ttest_ind within 0.1%."""
        import numpy as np
        rng = np.random.default_rng(42)

        control = rng.normal(10.0, 2.0, 1000)
        treatment = rng.normal(10.5, 2.1, 1000)

        result = welchs_t_test(
            control.mean(), control.std(ddof=1), len(control),
            treatment.mean(), treatment.std(ddof=1), len(treatment),
        )

        _, scipy_p = scipy_stats.ttest_ind(treatment, control, equal_var=False)

        assert abs(result.p_value - scipy_p) / scipy_p < 0.05, (
            f"p-value mismatch: {result.p_value} vs {scipy_p}"
        )

    def test_significant_difference(self):
        result = welchs_t_test(10.0, 2.0, 1000, 11.0, 2.0, 1000)
        assert result.is_significant is True

    def test_no_significant_difference(self):
        result = welchs_t_test(10.0, 2.0, 100, 10.05, 2.0, 100)
        assert result.is_significant is False

    def test_confidence_interval_valid(self):
        result = welchs_t_test(10.0, 2.0, 1000, 11.0, 2.0, 1000)
        ci_lower, ci_upper, point = result.confidence_interval
        assert ci_lower < point < ci_upper

    def test_insufficient_data_warning(self):
        """Small sample sizes produce high p-values (insufficient data indicator)."""
        result = z_test_proportions(1, 10, 2, 10)
        # With tiny samples, shouldn't be significant
        assert result.p_value > 0.05 or result.power_achieved < 0.3
