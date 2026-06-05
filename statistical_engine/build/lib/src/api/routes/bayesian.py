"""Bayesian API routes for the statistical engine (FR-105)."""

from fastapi import APIRouter
from pydantic import BaseModel, Field

from ...core.bayesian import beta_binomial_analysis, normal_analysis

router = APIRouter(prefix="/stats/v1/bayesian", tags=["bayesian"])


class BayesianConversionRequest(BaseModel):
    control_successes: int = Field(ge=0)
    control_trials: int = Field(gt=0)
    treatment_successes: int = Field(ge=0)
    treatment_trials: int = Field(gt=0)
    prior_alpha: float = Field(default=1.0, gt=0)
    prior_beta: float = Field(default=1.0, gt=0)
    rope: float = Field(default=0.005, ge=0)


class BayesianContinuousRequest(BaseModel):
    control_mean: float
    control_std: float = Field(gt=0)
    control_n: int = Field(gt=0)
    treatment_mean: float
    treatment_std: float = Field(gt=0)
    treatment_n: int = Field(gt=0)
    rope: float = Field(default=0.01, ge=0)


@router.post("/conversion")
async def bayesian_conversion(request: BayesianConversionRequest):
    """Bayesian analysis for conversion rate metrics."""
    result = beta_binomial_analysis(
        control_successes=request.control_successes,
        control_trials=request.control_trials,
        treatment_successes=request.treatment_successes,
        treatment_trials=request.treatment_trials,
        prior_alpha=request.prior_alpha,
        prior_beta=request.prior_beta,
        rope=request.rope,
    )
    return _serialize_result(result)


@router.post("/continuous")
async def bayesian_continuous(request: BayesianContinuousRequest):
    """Bayesian analysis for continuous metrics."""
    result = normal_analysis(
        control_mean=request.control_mean,
        control_std=request.control_std,
        control_n=request.control_n,
        treatment_mean=request.treatment_mean,
        treatment_std=request.treatment_std,
        treatment_n=request.treatment_n,
        rope=request.rope,
    )
    return _serialize_result(result)


def _serialize_result(result: dict) -> dict:
    """Convert dataclass results to serializable dicts."""
    serialized = {}
    for key, value in result.items():
        if hasattr(value, "__dict__"):
            serialized[key] = {
                k: list(v) if isinstance(v, tuple) else v
                for k, v in value.__dict__.items()
            }
        elif isinstance(value, dict):
            serialized[key] = {
                k: list(v) if isinstance(v, tuple) else v
                for k, v in value.items()
            }
        else:
            serialized[key] = value
    return serialized
