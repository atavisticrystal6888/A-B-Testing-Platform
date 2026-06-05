"""Sample size and power calculations."""
from __future__ import annotations

import math

from scipy import stats


def sample_size_proportions(
    baseline_rate: float,
    minimum_detectable_effect: float,
    significance_level: float = 0.05,
    power: float = 0.80,
    num_variants: int = 2,
    correction_method: str | None = None,
) -> dict:
    """
    Calculate required sample size per variant for a two-proportion z-test.

    Uses the formula:
    n = (z_{α/2} + z_β)² * (p₁(1-p₁) + p₂(1-p₂)) / (p₂ - p₁)²
    """
    p1 = baseline_rate
    p2 = baseline_rate + minimum_detectable_effect

    if p1 <= 0 or p1 >= 1 or p2 <= 0 or p2 >= 1:
        raise ValueError("Rates must be between 0 and 1")

    # Apply Bonferroni correction for multiple comparisons
    adjusted_alpha = significance_level
    if correction_method == "bonferroni" and num_variants > 2:
        adjusted_alpha = significance_level / (num_variants - 1)

    z_alpha = stats.norm.ppf(1 - adjusted_alpha / 2)
    z_beta = stats.norm.ppf(power)

    numerator = (z_alpha + z_beta) ** 2 * (p1 * (1 - p1) + p2 * (1 - p2))
    denominator = (p2 - p1) ** 2

    n_per_variant = math.ceil(numerator / denominator)

    return {
        "sample_size_per_variant": n_per_variant,
        "total_sample_size": n_per_variant * num_variants,
        "baseline_rate": p1,
        "minimum_detectable_effect": minimum_detectable_effect,
        "significance_level": significance_level,
        "power": power,
        "num_variants": num_variants,
        "correction_method": correction_method,
    }


def sample_size_continuous(
    baseline_mean: float,
    baseline_std: float,
    minimum_detectable_effect: float,
    significance_level: float = 0.05,
    power: float = 0.80,
    num_variants: int = 2,
) -> dict:
    """Calculate required sample size for continuous metric comparison."""
    z_alpha = stats.norm.ppf(1 - significance_level / 2)
    z_beta = stats.norm.ppf(power)

    # n = 2 * (z_α/2 + z_β)² * σ² / δ²
    n_per_variant = math.ceil(
        2 * (z_alpha + z_beta) ** 2 * baseline_std ** 2 / minimum_detectable_effect ** 2
    )

    return {
        "sample_size_per_variant": n_per_variant,
        "total_sample_size": n_per_variant * num_variants,
        "baseline_mean": baseline_mean,
        "baseline_std": baseline_std,
        "minimum_detectable_effect": minimum_detectable_effect,
        "significance_level": significance_level,
        "power": power,
        "num_variants": num_variants,
    }


def achieved_power_proportions(
    p_c: float,
    p_t: float,
    n_per_variant: int,
    significance_level: float = 0.05,
) -> float:
    """Calculate achieved power given observed rates and sample sizes."""
    if p_c <= 0 or p_c >= 1 or p_t <= 0 or p_t >= 1 or n_per_variant <= 0:
        return 0.0

    se = math.sqrt(p_c * (1 - p_c) / n_per_variant + p_t * (1 - p_t) / n_per_variant)
    if se <= 0:
        return 0.0

    z_alpha = stats.norm.ppf(1 - significance_level / 2)
    z_power = abs(p_t - p_c) / se - z_alpha

    return float(stats.norm.cdf(z_power))
