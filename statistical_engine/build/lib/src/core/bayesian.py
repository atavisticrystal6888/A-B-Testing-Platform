"""
Bayesian A/B testing analysis using conjugate priors (FR-105).
Beta-Binomial for conversion metrics, Normal-Normal for continuous.
"""

from dataclasses import dataclass

import numpy as np
from scipy import stats


@dataclass
class BayesianResult:
    probability_best: float
    expected_loss: float
    credible_interval: tuple[float, float]
    posterior_mean: float
    posterior_std: float
    rope_probability: float  # Region of Practical Equivalence


def beta_binomial_analysis(
    control_successes: int,
    control_trials: int,
    treatment_successes: int,
    treatment_trials: int,
    prior_alpha: float = 1.0,
    prior_beta: float = 1.0,
    rope: float = 0.005,
    n_samples: int = 100_000,
) -> dict:
    """
    Bayesian analysis for conversion rate metrics using Beta-Binomial model.
    """
    # Posterior distributions
    alpha_c = prior_alpha + control_successes
    beta_c = prior_beta + (control_trials - control_successes)
    alpha_t = prior_alpha + treatment_successes
    beta_t = prior_beta + (treatment_trials - treatment_successes)

    # Monte Carlo samples
    rng = np.random.default_rng(42)
    control_samples = rng.beta(alpha_c, beta_c, n_samples)
    treatment_samples = rng.beta(alpha_t, beta_t, n_samples)

    diff = treatment_samples - control_samples

    # Probability treatment is better
    prob_best = float(np.mean(diff > 0))

    # Expected loss (risk) if choosing treatment
    expected_loss = float(np.mean(np.maximum(control_samples - treatment_samples, 0)))

    # 95% HDI (Highest Density Interval)
    hdi = _hdi(diff, 0.95)

    # ROPE probability
    rope_prob = float(np.mean(np.abs(diff) < rope))

    return {
        "control": BayesianResult(
            probability_best=1 - prob_best,
            expected_loss=float(np.mean(np.maximum(treatment_samples - control_samples, 0))),
            credible_interval=(float(stats.beta.ppf(0.025, alpha_c, beta_c)),
                               float(stats.beta.ppf(0.975, alpha_c, beta_c))),
            posterior_mean=float(alpha_c / (alpha_c + beta_c)),
            posterior_std=float(np.sqrt(alpha_c * beta_c / ((alpha_c + beta_c) ** 2 * (alpha_c + beta_c + 1)))),
            rope_probability=rope_prob,
        ),
        "treatment": BayesianResult(
            probability_best=prob_best,
            expected_loss=expected_loss,
            credible_interval=(float(stats.beta.ppf(0.025, alpha_t, beta_t)),
                               float(stats.beta.ppf(0.975, alpha_t, beta_t))),
            posterior_mean=float(alpha_t / (alpha_t + beta_t)),
            posterior_std=float(np.sqrt(alpha_t * beta_t / ((alpha_t + beta_t) ** 2 * (alpha_t + beta_t + 1)))),
            rope_probability=rope_prob,
        ),
        "difference": {
            "mean": float(np.mean(diff)),
            "std": float(np.std(diff)),
            "hdi_95": hdi,
            "prob_positive": prob_best,
            "rope_probability": rope_prob,
        },
    }


def normal_analysis(
    control_mean: float,
    control_std: float,
    control_n: int,
    treatment_mean: float,
    treatment_std: float,
    treatment_n: int,
    rope: float = 0.01,
    n_samples: int = 100_000,
) -> dict:
    """
    Bayesian analysis for continuous metrics using Normal-Normal model.
    """
    # Posterior parameters (non-informative prior)
    post_mean_c = control_mean
    post_std_c = control_std / np.sqrt(control_n)
    post_mean_t = treatment_mean
    post_std_t = treatment_std / np.sqrt(treatment_n)

    rng = np.random.default_rng(42)
    control_samples = rng.normal(post_mean_c, post_std_c, n_samples)
    treatment_samples = rng.normal(post_mean_t, post_std_t, n_samples)

    diff = treatment_samples - control_samples
    prob_best = float(np.mean(diff > 0))
    expected_loss = float(np.mean(np.maximum(control_samples - treatment_samples, 0)))
    hdi = _hdi(diff, 0.95)
    rope_prob = float(np.mean(np.abs(diff) < rope))

    return {
        "difference": {
            "mean": float(np.mean(diff)),
            "std": float(np.std(diff)),
            "hdi_95": hdi,
            "prob_positive": prob_best,
            "rope_probability": rope_prob,
        },
        "probability_best": prob_best,
        "expected_loss": expected_loss,
    }


def _hdi(samples: np.ndarray, credible_mass: float = 0.95) -> tuple[float, float]:
    """Compute Highest Density Interval."""
    sorted_samples = np.sort(samples)
    n = len(sorted_samples)
    interval_size = int(np.ceil(credible_mass * n))

    widths = sorted_samples[interval_size:] - sorted_samples[:n - interval_size]
    min_idx = int(np.argmin(widths))

    return (float(sorted_samples[min_idx]), float(sorted_samples[min_idx + interval_size]))
