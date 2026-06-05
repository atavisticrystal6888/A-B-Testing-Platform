"""Tests for sample size and power calculations."""
import pytest

from src.core.power import (
    achieved_power_proportions,
    sample_size_continuous,
    sample_size_proportions,
)


class TestSampleSizeProportions:
    """Tests for proportions sample size calculator."""

    def test_known_result(self):
        """Standard A/B test: 10% base, 2pp MDE, 80% power, 5% alpha → ~3842 per arm."""
        result = sample_size_proportions(
            baseline_rate=0.10,
            minimum_detectable_effect=0.02,
            significance_level=0.05,
            power=0.80,
        )
        # Standard formula gives ~3842
        assert 3500 < result["sample_size_per_variant"] < 4200

    def test_smaller_effect_needs_more_samples(self):
        large_effect = sample_size_proportions(0.10, 0.05)
        small_effect = sample_size_proportions(0.10, 0.01)
        assert small_effect["sample_size_per_variant"] > large_effect["sample_size_per_variant"]

    def test_higher_power_needs_more_samples(self):
        low_power = sample_size_proportions(0.10, 0.02, power=0.80)
        high_power = sample_size_proportions(0.10, 0.02, power=0.95)
        assert high_power["sample_size_per_variant"] > low_power["sample_size_per_variant"]

    def test_bonferroni_correction(self):
        """Bonferroni correction increases sample size for multivariate tests."""
        no_correction = sample_size_proportions(0.10, 0.02, num_variants=3)
        with_correction = sample_size_proportions(
            0.10, 0.02, num_variants=3, correction_method="bonferroni"
        )
        assert with_correction["sample_size_per_variant"] > no_correction["sample_size_per_variant"]

    def test_invalid_rates(self):
        with pytest.raises(ValueError):
            sample_size_proportions(0.0, 0.02)
        with pytest.raises(ValueError):
            sample_size_proportions(0.99, 0.02)  # p2 would be > 1

    def test_total_sample_size(self):
        result = sample_size_proportions(0.10, 0.02, num_variants=3)
        assert result["total_sample_size"] == result["sample_size_per_variant"] * 3


class TestSampleSizeContinuous:
    """Tests for continuous metric sample size calculator."""

    def test_known_result(self):
        result = sample_size_continuous(
            baseline_mean=10.0,
            baseline_std=2.0,
            minimum_detectable_effect=0.5,
        )
        assert result["sample_size_per_variant"] > 0

    def test_larger_std_needs_more_samples(self):
        low_std = sample_size_continuous(10.0, 1.0, 0.5)
        high_std = sample_size_continuous(10.0, 5.0, 0.5)
        assert high_std["sample_size_per_variant"] > low_std["sample_size_per_variant"]


class TestAchievedPower:
    """Tests for achieved power calculation."""

    def test_large_sample_high_power(self):
        power = achieved_power_proportions(0.10, 0.15, 10000)
        assert power > 0.95

    def test_small_sample_low_power(self):
        power = achieved_power_proportions(0.10, 0.11, 100)
        assert power < 0.5

    def test_invalid_rates(self):
        assert achieved_power_proportions(0.0, 0.1, 1000) == 0.0
        assert achieved_power_proportions(0.1, 0.0, 1000) == 0.0
