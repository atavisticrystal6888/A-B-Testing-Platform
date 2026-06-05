"""Analysis API routes: POST /stats/v1/analyze/{experiment_id}."""
from __future__ import annotations

import logging
import time
from datetime import UTC, datetime

from fastapi import APIRouter

from src.core.frequentist import z_test_proportions
from src.core.power import sample_size_proportions
from src.core.sequential import evaluate_sequential
from src.models.analysis import (
    AnalysisRequest,
    AnalysisResponse,
    ConfidenceInterval,
    EffectSize,
    FrequentistResult,
    GuardrailStatus,
    MetricResult,
    Recommendation,
    SampleSizeCalc,
    SequentialResult,
    VariantStats,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# In-memory results cache (replace with Redis/DB in production)
_results_cache: dict[str, AnalysisResponse] = {}


@router.post("/analyze/{experiment_id}")
async def analyze_experiment(
    experiment_id: str,
    request: AnalysisRequest,
) -> AnalysisResponse:
    """
    POST /stats/v1/analyze/{experiment_id}
    Run full statistical analysis on an experiment.
    """
    start = time.perf_counter()

    metric_results = []
    guardrail_breaches: list[str] = []
    overall_has_sufficient = True

    for metric in request.metrics:
        if metric.role == "guardrail":
            result = _analyze_guardrail(metric, request)
            if result.guardrail_status and result.guardrail_status.is_breached:
                guardrail_breaches.append(metric.metric_key)
        else:
            result = _analyze_metric(metric, request)
            if result.sample_size_calculation and not result.sample_size_calculation.is_sufficient:
                overall_has_sufficient = False

        metric_results.append(result)

    elapsed_ms = int((time.perf_counter() - start) * 1000)
    overall_status = "sufficient_data" if overall_has_sufficient else "insufficient_data"
    if guardrail_breaches:
        overall_status = "guardrail_breach"

    response = AnalysisResponse(
        experiment_id=experiment_id,
        computed_at=datetime.now(UTC),
        computation_time_ms=elapsed_ms,
        metrics=metric_results,
        overall_status=overall_status,
        guardrail_breaches=guardrail_breaches,
    )

    _results_cache[experiment_id] = response
    return response


@router.get("/analyze/{experiment_id}/results")
async def get_results(experiment_id: str):
    """GET /stats/v1/analyze/{experiment_id}/results - cached results."""
    if experiment_id in _results_cache:
        return _results_cache[experiment_id]
    return {"error": "not_found", "message": "No analysis results found for this experiment"}


def _analyze_metric(metric, request: AnalysisRequest) -> MetricResult:
    """Run frequentist analysis for a metric."""
    # For now, use placeholder data from the request
    # In production, this fetches from experiment_results_daily
    control = next((v for v in request.variants if v.is_control), None)
    treatment = next((v for v in request.variants if not v.is_control), None)

    if not control or not treatment:
        return MetricResult(
            metric_key=metric.metric_key,
            role=metric.role.value,
            recommendation=Recommendation(
                action="insufficient_data",
                message="Need at least one control and one treatment variant.",
            ),
        )

    # Placeholder stats (in production, fetched from DB)
    control_n = 1000
    treatment_n = 1000
    control_conversions = 100
    treatment_conversions = 120

    freq_result = z_test_proportions(
        control_conversions, control_n,
        treatment_conversions, treatment_n,
        request.config.significance_level,
    )

    variants = [
        VariantStats(
            variant_key=control.variant_key,
            sample_size=control_n,
            conversions=control_conversions,
            conversion_rate=control_conversions / control_n,
            mean=control_conversions / control_n,
        ),
        VariantStats(
            variant_key=treatment.variant_key,
            sample_size=treatment_n,
            conversions=treatment_conversions,
            conversion_rate=treatment_conversions / treatment_n,
            mean=treatment_conversions / treatment_n,
        ),
    ]

    ss_calc = sample_size_proportions(
        baseline_rate=control_conversions / control_n,
        minimum_detectable_effect=0.02,
        significance_level=request.config.significance_level,
        power=request.config.power,
    )

    sample_size_result = SampleSizeCalc(
        minimum_required=ss_calc["sample_size_per_variant"],
        current_total=control_n + treatment_n,
        is_sufficient=(control_n + treatment_n) >= ss_calc["total_sample_size"],
        baseline_rate=control_conversions / control_n,
        minimum_detectable_effect=0.02,
        power=request.config.power,
        significance_level=request.config.significance_level,
    )

    # Sequential analysis if configured
    sequential = None
    if request.config.sequential_analysis:
        info_fraction = min(1.0, (control_n + treatment_n) / ss_calc["total_sample_size"])
        se = (freq_result.confidence_interval[2] - freq_result.confidence_interval[0]) / 3.92
        z_stat = freq_result.effect_size_absolute / se if se > 0 else 0
        seq_result = evaluate_sequential(
            z_stat, info_fraction,
            request.config.significance_level,
            request.config.spending_function or "obrien_fleming",
        )
        sequential = SequentialResult(**seq_result)

    # Recommendation
    if not sample_size_result.is_sufficient:
        recommendation = Recommendation(
            action="insufficient_data",
            message=f"Only {sample_size_result.current_total} of {sample_size_result.minimum_required * 2} required samples collected. Continue running.",
        )
    elif freq_result.is_significant:
        recommendation = Recommendation(
            action="significant_winner",
            winning_variant=treatment.variant_key,
            confidence="high",
            message=f"Treatment shows a statistically significant improvement (p={freq_result.p_value:.4f}).",
        )
    else:
        recommendation = Recommendation(
            action="no_significant_difference",
            message=f"No statistically significant difference detected (p={freq_result.p_value:.4f}).",
        )

    return MetricResult(
        metric_key=metric.metric_key,
        metric_type=metric.metric_type.value,
        role=metric.role.value,
        variants=variants,
        frequentist=FrequentistResult(
            test_method=freq_result.test_method,
            p_value=freq_result.p_value,
            confidence_level=1 - request.config.significance_level,
            confidence_interval=ConfidenceInterval(
                lower=freq_result.confidence_interval[0],
                upper=freq_result.confidence_interval[1],
                point_estimate=freq_result.confidence_interval[2],
            ),
            effect_size=EffectSize(
                absolute=freq_result.effect_size_absolute,
                relative=freq_result.effect_size_relative,
                cohens_h=freq_result.cohens_h,
            ),
            power_achieved=freq_result.power_achieved,
            is_significant=freq_result.is_significant,
        ),
        sequential=sequential,
        sample_size_calculation=sample_size_result,
        recommendation=recommendation,
    )


def _analyze_guardrail(metric, request: AnalysisRequest) -> MetricResult:
    """Evaluate a guardrail metric."""
    # Placeholder current value (in production, computed from data)
    current_value = 0.03

    threshold = metric.guardrail_threshold or 0.05
    direction = metric.guardrail_direction.value if metric.guardrail_direction else "above"

    is_breached = (
        current_value > threshold if direction == "above" else current_value < threshold
    )

    return MetricResult(
        metric_key=metric.metric_key,
        role="guardrail",
        guardrail_status=GuardrailStatus(
            threshold=threshold,
            direction=direction,
            current_value=current_value,
            is_breached=is_breached,
        ),
    )
