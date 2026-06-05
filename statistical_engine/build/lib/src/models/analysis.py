"""Pydantic models for analysis request/response per statistical-api.md."""
from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class MetricType(str, Enum):
    COUNT = "count"
    RATIO = "ratio"
    SUM = "sum"
    FUNNEL = "funnel"


class MetricRole(str, Enum):
    PRIMARY = "primary"
    SECONDARY = "secondary"
    GUARDRAIL = "guardrail"


class GuardrailDirection(str, Enum):
    ABOVE = "above"
    BELOW = "below"


class MetricInput(BaseModel):
    metric_definition_id: str
    metric_key: str
    metric_type: MetricType
    role: MetricRole
    guardrail_threshold: Optional[float] = None
    guardrail_direction: Optional[GuardrailDirection] = None


class VariantInput(BaseModel):
    variant_id: str
    variant_key: str
    is_control: bool


class AnalysisConfig(BaseModel):
    significance_level: float = 0.05
    power: float = 0.80
    correction_method: Optional[str] = None
    sequential_analysis: bool = False
    spending_function: Optional[str] = "obrien_fleming"
    analysis_types: list[str] = Field(default_factory=lambda: ["frequentist"])


class AnalysisRequest(BaseModel):
    tenant_id: str
    experiment_id: str
    metrics: list[MetricInput]
    variants: list[VariantInput]
    config: AnalysisConfig = Field(default_factory=AnalysisConfig)


class ConfidenceInterval(BaseModel):
    lower: float
    upper: float
    point_estimate: float


class EffectSize(BaseModel):
    absolute: float
    relative: float
    cohens_h: Optional[float] = None


class FrequentistResult(BaseModel):
    test_method: str
    p_value: float
    adjusted_p_value: Optional[float] = None
    correction_method: Optional[str] = None
    confidence_level: float = 0.95
    confidence_interval: ConfidenceInterval
    effect_size: EffectSize
    power_achieved: float
    is_significant: bool


class BayesianPosterior(BaseModel):
    alpha: float
    beta: float


class BayesianResult(BaseModel):
    model: str
    prior: dict
    posteriors: dict[str, BayesianPosterior]
    probability_to_be_best: dict[str, float]
    credible_interval: ConfidenceInterval
    expected_loss: dict[str, float]


class SequentialResult(BaseModel):
    spending_function: str
    information_fraction: float
    nominal_alpha: float
    adjusted_critical_value: float
    observed_z_statistic: float
    can_reject: bool


class SampleSizeCalc(BaseModel):
    minimum_required: int
    current_total: int
    is_sufficient: bool
    baseline_rate: Optional[float] = None
    minimum_detectable_effect: Optional[float] = None
    power: float = 0.80
    significance_level: float = 0.05


class Recommendation(BaseModel):
    action: str
    winning_variant: Optional[str] = None
    confidence: Optional[str] = None
    message: str


class VariantStats(BaseModel):
    variant_key: str
    sample_size: int
    conversions: Optional[int] = None
    conversion_rate: Optional[float] = None
    mean: Optional[float] = None
    std_dev: Optional[float] = None


class GuardrailStatus(BaseModel):
    threshold: float
    direction: str
    current_value: float
    is_breached: bool


class MetricResult(BaseModel):
    metric_key: str
    metric_type: Optional[str] = None
    role: str
    variants: Optional[list[VariantStats]] = None
    frequentist: Optional[FrequentistResult] = None
    bayesian: Optional[BayesianResult] = None
    sequential: Optional[SequentialResult] = None
    sample_size_calculation: Optional[SampleSizeCalc] = None
    recommendation: Optional[Recommendation] = None
    guardrail_status: Optional[GuardrailStatus] = None


class AnalysisResponse(BaseModel):
    experiment_id: str
    computed_at: datetime
    computation_time_ms: int
    metrics: list[MetricResult]
    overall_status: str
    guardrail_breaches: list[str] = Field(default_factory=list)
