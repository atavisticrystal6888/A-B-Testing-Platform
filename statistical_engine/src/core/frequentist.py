"""Frequentist statistical analysis: z-test for proportions, Welch's t-test."""
from __future__ import annotations

import math
from dataclasses import dataclass

from scipy import stats


@dataclass
class FrequentistTestResult:
    test_method: str
    p_value: float
    confidence_interval: tuple[float, float, float]  # lower, upper, point_estimate
    effect_size_absolute: float
    effect_size_relative: float
    cohens_h: float | None
    power_achieved: float
    is_significant: bool


def z_test_proportions(
    control_conversions: int,
    control_n: int,
    treatment_conversions: int,
    treatment_n: int,
    significance_level: float = 0.05,
) -> FrequentistTestResult:
    """Two-proportion z-test for conversion rate comparison."""
    p_c = control_conversions / control_n if control_n > 0 else 0.0
    p_t = treatment_conversions / treatment_n if treatment_n > 0 else 0.0

    # Pooled proportion
    p_pool = (control_conversions + treatment_conversions) / (control_n + treatment_n)

    # Standard error
    se = math.sqrt(p_pool * (1 - p_pool) * (1 / control_n + 1 / treatment_n)) if p_pool > 0 and p_pool < 1 else 1e-10

    # Z-statistic
    z_stat = (p_t - p_c) / se if se > 0 else 0.0

    # Two-sided p-value
    p_value = 2 * (1 - stats.norm.cdf(abs(z_stat)))

    # Confidence interval for difference
    se_diff = math.sqrt(
        p_c * (1 - p_c) / control_n + p_t * (1 - p_t) / treatment_n
    ) if control_n > 0 and treatment_n > 0 else 1e-10

    z_crit = stats.norm.ppf(1 - significance_level / 2)
    diff = p_t - p_c
    ci_lower = diff - z_crit * se_diff
    ci_upper = diff + z_crit * se_diff

    # Effect sizes
    relative_effect = diff / p_c if p_c > 0 else 0.0
    cohens_h = 2 * (math.asin(math.sqrt(p_t)) - math.asin(math.sqrt(p_c)))

    # Achieved power
    power = _compute_power_proportions(p_c, p_t, control_n, treatment_n, significance_level)

    return FrequentistTestResult(
        test_method="z_test_proportions",
        p_value=float(p_value),
        confidence_interval=(float(ci_lower), float(ci_upper), float(diff)),
        effect_size_absolute=float(diff),
        effect_size_relative=float(relative_effect),
        cohens_h=float(cohens_h),
        power_achieved=float(power),
        is_significant=bool(p_value < significance_level),
    )


def welchs_t_test(
    control_mean: float,
    control_std: float,
    control_n: int,
    treatment_mean: float,
    treatment_std: float,
    treatment_n: int,
    significance_level: float = 0.05,
) -> FrequentistTestResult:
    """Welch's t-test for continuous metrics."""
    diff = treatment_mean - control_mean

    # Standard error of difference
    se = math.sqrt(
        control_std**2 / control_n + treatment_std**2 / treatment_n
    ) if control_n > 0 and treatment_n > 0 else 1e-10

    # Welch-Satterthwaite degrees of freedom
    num = (control_std**2 / control_n + treatment_std**2 / treatment_n) ** 2
    denom = (
        (control_std**2 / control_n) ** 2 / (control_n - 1)
        + (treatment_std**2 / treatment_n) ** 2 / (treatment_n - 1)
    ) if control_n > 1 and treatment_n > 1 else 1.0
    df = num / denom if denom > 0 else 1.0

    # t-statistic
    t_stat = diff / se if se > 0 else 0.0

    # Two-sided p-value
    p_value = 2 * (1 - stats.t.cdf(abs(t_stat), df))

    # Confidence interval
    t_crit = stats.t.ppf(1 - significance_level / 2, df)
    ci_lower = diff - t_crit * se
    ci_upper = diff + t_crit * se

    # Cohen's d
    pooled_std = math.sqrt(
        ((control_n - 1) * control_std**2 + (treatment_n - 1) * treatment_std**2)
        / (control_n + treatment_n - 2)
    ) if control_n + treatment_n > 2 else 1.0
    cohens_d = diff / pooled_std if pooled_std > 0 else 0.0

    relative_effect = diff / control_mean if control_mean != 0 else 0.0

    # Power (approximate using normal approximation)
    power = _compute_power_continuous(diff, se, significance_level)

    return FrequentistTestResult(
        test_method="welchs_t_test",
        p_value=float(p_value),
        confidence_interval=(float(ci_lower), float(ci_upper), float(diff)),
        effect_size_absolute=float(diff),
        effect_size_relative=float(relative_effect),
        cohens_h=float(cohens_d),
        power_achieved=float(power),
        is_significant=bool(p_value < significance_level),
    )


def _compute_power_proportions(
    p_c: float, p_t: float, n_c: int, n_t: int, alpha: float
) -> float:
    """Compute achieved power for two-proportion z-test."""
    if p_c <= 0 or p_c >= 1 or p_t <= 0 or p_t >= 1:
        return 0.0

    se = math.sqrt(p_c * (1 - p_c) / n_c + p_t * (1 - p_t) / n_t)
    if se <= 0:
        return 0.0

    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_power = abs(p_t - p_c) / se - z_alpha

    return float(stats.norm.cdf(z_power))


def _compute_power_continuous(diff: float, se: float, alpha: float) -> float:
    """Compute achieved power for continuous metrics."""
    if se <= 0:
        return 0.0

    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_power = abs(diff) / se - z_alpha

    return float(stats.norm.cdf(z_power))
