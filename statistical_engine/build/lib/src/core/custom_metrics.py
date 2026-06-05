"""Custom metric computation: ratio metrics and funnel metrics (FR-290)."""

import math
from dataclasses import dataclass
from typing import List


@dataclass
class RatioMetricResult:
    """Result of ratio metric computation."""
    numerator_count: int
    denominator_count: int
    ratio: float
    ci_lower: float
    ci_upper: float


@dataclass
class FunnelStep:
    """Individual funnel step result."""
    name: str
    entered: int
    completed: int
    rate: float


@dataclass
class FunnelMetricResult:
    """Result of funnel metric computation."""
    steps: List[FunnelStep]
    overall_conversion: float


def compute_ratio_metric(
    numerator_count: int,
    denominator_count: int,
    confidence: float = 0.95,
) -> RatioMetricResult:
    """Compute a ratio metric (e.g., revenue_per_user = total_revenue / total_users)."""
    if denominator_count == 0:
        return RatioMetricResult(
            numerator_count=numerator_count,
            denominator_count=0,
            ratio=0.0,
            ci_lower=0.0,
            ci_upper=0.0,
        )

    ratio = numerator_count / denominator_count

    # Use normal approximation for CI
    from scipy import stats

    z = stats.norm.ppf(1 - (1 - confidence) / 2)

    # For count ratios, use Poisson-like variance
    se = math.sqrt(ratio / denominator_count) if denominator_count > 0 else 0

    ci_lower = max(0, ratio - z * se)
    ci_upper = ratio + z * se

    return RatioMetricResult(
        numerator_count=numerator_count,
        denominator_count=denominator_count,
        ratio=ratio,
        ci_lower=ci_lower,
        ci_upper=ci_upper,
    )


def compute_funnel_metric(
    steps: List[dict],
) -> FunnelMetricResult:
    """
    Compute funnel metric from ordered steps.

    Each step dict should have:
      - name: str
      - entered: int
      - completed: int
    """
    funnel_steps = []

    for step_data in steps:
        entered = step_data["entered"]
        completed = step_data["completed"]
        rate = completed / entered if entered > 0 else 0.0

        funnel_steps.append(
            FunnelStep(
                name=step_data["name"],
                entered=entered,
                completed=completed,
                rate=rate,
            )
        )

    # Overall conversion = last step completed / first step entered
    if funnel_steps and funnel_steps[0].entered > 0:
        overall = funnel_steps[-1].completed / funnel_steps[0].entered
    else:
        overall = 0.0

    return FunnelMetricResult(
        steps=funnel_steps,
        overall_conversion=overall,
    )


def compute_ratio_metric_comparison(
    control_num: int,
    control_den: int,
    treatment_num: int,
    treatment_den: int,
    confidence: float = 0.95,
) -> dict:
    """Compare ratio metrics between control and treatment."""
    from scipy import stats

    control_ratio = control_num / control_den if control_den > 0 else 0
    treatment_ratio = treatment_num / treatment_den if treatment_den > 0 else 0

    diff = treatment_ratio - control_ratio
    relative_diff = diff / control_ratio if control_ratio > 0 else 0

    # Delta method variance for ratio comparison
    se_control = math.sqrt(control_ratio / control_den) if control_den > 0 else 0
    se_treatment = math.sqrt(treatment_ratio / treatment_den) if treatment_den > 0 else 0
    se_diff = math.sqrt(se_control**2 + se_treatment**2)

    z = stats.norm.ppf(1 - (1 - confidence) / 2)

    return {
        "control_ratio": control_ratio,
        "treatment_ratio": treatment_ratio,
        "absolute_difference": diff,
        "relative_difference": relative_diff,
        "ci_lower": diff - z * se_diff,
        "ci_upper": diff + z * se_diff,
        "p_value": 2 * (1 - stats.norm.cdf(abs(diff / se_diff))) if se_diff > 0 else 1.0,
    }
