"""Tests for sequential analysis: O'Brien-Fleming spending function."""
import math

import pytest
from scipy import stats

from src.core.sequential import (
    evaluate_sequential,
    obrien_fleming_boundary,
    pocock_boundary,
)


class TestOBrienFleming:
    """Tests for O'Brien-Fleming alpha-spending function."""

    def test_boundary_at_full_information(self):
        """At information fraction = 1.0, nominal alpha ≈ overall alpha."""
        nominal_alpha, critical_value = obrien_fleming_boundary(1.0, 0.05)
        assert abs(nominal_alpha - 0.05) < 0.01

    def test_boundary_decreases_with_less_information(self):
        """Earlier looks require more extreme z-values (more conservative)."""
        _, cv_early = obrien_fleming_boundary(0.25, 0.05)
        _, cv_late = obrien_fleming_boundary(0.75, 0.05)
        assert cv_early > cv_late

    def test_nominal_alpha_increases_with_information(self):
        """More accumulated information allows larger alpha spending."""
        alpha_25, _ = obrien_fleming_boundary(0.25, 0.05)
        alpha_75, _ = obrien_fleming_boundary(0.75, 0.05)
        assert alpha_25 < alpha_75

    def test_invalid_information_fraction(self):
        with pytest.raises(ValueError):
            obrien_fleming_boundary(0.0, 0.05)
        with pytest.raises(ValueError):
            obrien_fleming_boundary(1.5, 0.05)

    def test_known_boundary_values(self):
        """Verify against known O'Brien-Fleming boundaries."""
        # At 50% information, the boundary should be approximately z/sqrt(0.5)
        z_05 = stats.norm.ppf(0.975)  # ~1.96
        expected_cv = z_05 / math.sqrt(0.5)  # ~2.77

        _, cv = obrien_fleming_boundary(0.5, 0.05)
        assert abs(cv - expected_cv) < 0.01


class TestPocock:
    """Tests for Pocock spending function."""

    def test_boundary_produces_valid_alpha(self):
        nominal_alpha, cv = pocock_boundary(0.5, 0.05)
        assert 0 < nominal_alpha < 0.05
        assert cv > 0

    def test_invalid_fraction(self):
        with pytest.raises(ValueError):
            pocock_boundary(0.0, 0.05)


class TestEvaluateSequential:
    """Tests for sequential evaluation."""

    def test_reject_with_extreme_z(self):
        result = evaluate_sequential(5.0, 0.5, 0.05, "obrien_fleming")
        assert result["can_reject"] is True

    def test_no_reject_with_small_z(self):
        result = evaluate_sequential(0.5, 0.25, 0.05, "obrien_fleming")
        assert result["can_reject"] is False

    def test_result_structure(self):
        result = evaluate_sequential(2.0, 0.5, 0.05, "obrien_fleming")
        assert "spending_function" in result
        assert "information_fraction" in result
        assert "nominal_alpha" in result
        assert "adjusted_critical_value" in result
        assert "observed_z_statistic" in result
        assert "can_reject" in result

    def test_unknown_spending_function(self):
        with pytest.raises(ValueError):
            evaluate_sequential(2.0, 0.5, 0.05, "unknown")
