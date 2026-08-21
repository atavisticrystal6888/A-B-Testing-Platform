"""Tests for the days-to-significance projection (Roadmap #4).

Reuses the already-computed sample-size requirement (power.py); this module
adds no new statistics, only a division against the observed exposure rate.
"""
from src.core.projection import project_days_to_significance


class TestProjectDaysToSignificance:
    def test_estimate_case(self):
        # required 10_000/variant, 2 variants -> 20_000 total; current 12_000
        # remaining -> 8_000; at 500/day -> ceil(8000/500) = 16 days.
        result = project_days_to_significance(
            minimum_required_per_variant=10_000,
            current_total=12_000,
            num_variants=2,
            exposure_rate_per_day=500,
        )
        assert result == {"status": "estimate", "days_remaining": 16}

    def test_zero_remaining_is_zero_days(self):
        result = project_days_to_significance(
            minimum_required_per_variant=10_000,
            current_total=20_000,
            num_variants=2,
            exposure_rate_per_day=500,
        )
        assert result == {"status": "estimate", "days_remaining": 0}

    def test_rate_zero_is_insufficient_data(self):
        result = project_days_to_significance(
            minimum_required_per_variant=10_000,
            current_total=1_000,
            num_variants=2,
            exposure_rate_per_day=0,
        )
        assert result == {"status": "insufficient_data", "days_remaining": None}

    def test_huge_remaining_is_may_never(self):
        # required 1_000_000/variant, rate 10/day -> centuries away.
        result = project_days_to_significance(
            minimum_required_per_variant=1_000_000,
            current_total=0,
            num_variants=2,
            exposure_rate_per_day=10,
        )
        assert result == {"status": "may_never", "days_remaining": None}

    def test_missing_required_is_insufficient_data(self):
        result = project_days_to_significance(
            minimum_required_per_variant=None,
            current_total=1_000,
            num_variants=2,
            exposure_rate_per_day=500,
        )
        assert result == {"status": "insufficient_data", "days_remaining": None}
