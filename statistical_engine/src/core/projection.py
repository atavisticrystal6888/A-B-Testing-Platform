"""Days-to-significance projection (Roadmap #4).

Projects how many more days of traffic, at the currently observed exposure
rate, an experiment needs before it reaches the sample-size requirement
already computed by `power.sample_size_proportions`. This module adds no
new statistics — it is arithmetic over numbers the engine already produces.
"""
from __future__ import annotations

import math
from typing import Optional, TypedDict

# Product call: beyond a year out, a raw day-count reads as false precision
# and is more likely to mislead than inform, so we report "may never" instead.
MAX_DAYS_HORIZON = 365


class ProjectionResult(TypedDict):
    status: str
    days_remaining: Optional[int]


def project_days_to_significance(
    minimum_required_per_variant: Optional[int],
    current_total: int,
    num_variants: int,
    exposure_rate_per_day: Optional[float],
) -> ProjectionResult:
    """Estimate days remaining until enough total samples are collected.

    Args:
        minimum_required_per_variant: per-variant sample size requirement
            from `sample_size_calculation` (`SampleSizeCalc.minimum_required`
            / `sample_size_proportions()["sample_size_per_variant"]`), or
            None when no requirement could be computed for this metric.
        current_total: samples collected so far, across all variants.
        num_variants: number of variants in the experiment.
        exposure_rate_per_day: observed new-assignment rate (assignments/day).

    Returns:
        {"status": "estimate", "days_remaining": int} when a projection can
        be made (0 when already sufficient); {"status": "may_never",
        "days_remaining": None} when the horizon exceeds
        `MAX_DAYS_HORIZON` days at the current rate; {"status":
        "insufficient_data", "days_remaining": None} when there is no
        required-n to project against or no positive traffic rate to
        project with.
    """
    if minimum_required_per_variant is None:
        return {"status": "insufficient_data", "days_remaining": None}

    if not exposure_rate_per_day or exposure_rate_per_day <= 0:
        return {"status": "insufficient_data", "days_remaining": None}

    total_required = minimum_required_per_variant * num_variants
    remaining = total_required - current_total

    if remaining <= 0:
        return {"status": "estimate", "days_remaining": 0}

    days = math.ceil(remaining / exposure_rate_per_day)

    if days > MAX_DAYS_HORIZON:
        return {"status": "may_never", "days_remaining": None}

    return {"status": "estimate", "days_remaining": days}
