"""O'Brien-Fleming alpha-spending function for sequential analysis."""
from __future__ import annotations

import math

from scipy import stats


def obrien_fleming_boundary(
    information_fraction: float,
    overall_alpha: float = 0.05,
) -> tuple[float, float]:
    """
    Compute O'Brien-Fleming spending function boundary.

    Returns (nominal_alpha, critical_value) at the given information fraction.
    """
    if information_fraction <= 0 or information_fraction > 1:
        raise ValueError("Information fraction must be in (0, 1]")

    # O'Brien-Fleming spending: alpha_spent = 2 * (1 - Φ(z_{α/2} / sqrt(t)))
    z_alpha = stats.norm.ppf(1 - overall_alpha / 2)
    adjusted_z = z_alpha / math.sqrt(information_fraction)
    nominal_alpha = float(2 * (1 - stats.norm.cdf(adjusted_z)))

    return nominal_alpha, float(adjusted_z)


def pocock_boundary(
    information_fraction: float,
    overall_alpha: float = 0.05,
    num_looks: int = 5,
) -> tuple[float, float]:
    """
    Compute Pocock spending function boundary.
    Uses constant boundary approach.

    Returns (nominal_alpha, critical_value).
    """
    if information_fraction <= 0 or information_fraction > 1:
        raise ValueError("Information fraction must be in (0, 1]")

    # Pocock: alpha_spent = overall_alpha * ln(1 + (e - 1) * t)
    alpha_spent = overall_alpha * math.log(1 + (math.e - 1) * information_fraction)
    nominal_alpha = float(min(alpha_spent, overall_alpha))
    critical_value = float(stats.norm.ppf(1 - nominal_alpha / 2))

    return nominal_alpha, critical_value


def evaluate_sequential(
    z_statistic: float,
    information_fraction: float,
    overall_alpha: float = 0.05,
    spending_function: str = "obrien_fleming",
) -> dict:
    """
    Evaluate whether to reject the null at the current interim analysis.

    Returns dict with sequential analysis results.
    """
    if spending_function == "obrien_fleming":
        nominal_alpha, critical_value = obrien_fleming_boundary(
            information_fraction, overall_alpha
        )
    elif spending_function == "pocock":
        nominal_alpha, critical_value = pocock_boundary(
            information_fraction, overall_alpha
        )
    else:
        raise ValueError(f"Unknown spending function: {spending_function}")

    can_reject = bool(abs(z_statistic) > critical_value)

    return {
        "spending_function": spending_function,
        "information_fraction": information_fraction,
        "nominal_alpha": nominal_alpha,
        "adjusted_critical_value": critical_value,
        "observed_z_statistic": z_statistic,
        "can_reject": can_reject,
    }
