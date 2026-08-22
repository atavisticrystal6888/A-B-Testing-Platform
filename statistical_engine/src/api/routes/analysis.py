"""Analysis API routes: POST /stats/v1/analyze/{experiment_id}."""
from __future__ import annotations

import logging
import math
import time
from datetime import UTC, datetime

from fastapi import APIRouter

from src.core.frequentist import FrequentistTestResult, welchs_t_test, z_test_proportions
from src.core.power import sample_size_proportions
from src.core.projection import project_days_to_significance
from src.core.sequential import evaluate_sequential
from src.models.analysis import (
    AnalysisRequest,
    AnalysisResponse,
    ConfidenceInterval,
    EffectSize,
    FrequentistResult,
    GuardrailStatus,
    MetricInput,
    MetricResult,
    MetricRole,
    MetricType,
    ProjectionResult,
    Recommendation,
    SampleSizeCalc,
    SequentialResult,
    VariantInput,
    VariantStats,
    VariantStatsInput,
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
async def get_results(experiment_id: str) -> AnalysisResponse | dict[str, str]:
    """GET /stats/v1/analyze/{experiment_id}/results - cached results."""
    if experiment_id in _results_cache:
        return _results_cache[experiment_id]
    return {"error": "not_found", "message": "No analysis results found for this experiment"}


def _stats_for(metric: MetricInput, variant_key: str) -> VariantStatsInput:
    """Look up the caller-provided stats for a variant, defaulting to zeros."""
    for stats in metric.variant_stats:
        if stats.variant_key == variant_key:
            return stats
    return VariantStatsInput(variant_key=variant_key)


def _mean_and_std(stats: VariantStatsInput) -> tuple[float, float]:
    """Mean/std of the per-user value over the assigned population, with
    non-converters contributing zero (standard revenue-per-user treatment)."""
    n = stats.sample_size
    if n <= 0:
        return 0.0, 0.0
    mean = stats.sum_value / n
    # E[x^2] - mean^2, with Bessel's correction; clamp negatives from
    # floating-point roundoff.
    variance = max(0.0, (stats.sum_squared_value / n - mean**2) * (n / max(1, n - 1)))
    return mean, math.sqrt(variance)


def _variant_stats_list(
    metric: MetricInput, request: AnalysisRequest, continuous: bool
) -> list[VariantStats]:
    """Response stats for every variant, derived from the real counts."""
    result = []
    for variant in request.variants:
        stats = _stats_for(metric, variant.variant_key)
        rate = stats.conversions / stats.sample_size if stats.sample_size > 0 else None
        mean, std = _mean_and_std(stats)
        result.append(
            VariantStats(
                variant_key=variant.variant_key,
                sample_size=stats.sample_size,
                conversions=stats.conversions,
                conversion_rate=rate,
                mean=mean if continuous else rate,
                std_dev=std if continuous else None,
            )
        )
    return result


def _insufficient(metric: MetricInput, request: AnalysisRequest, message: str) -> MetricResult:
    continuous = metric.metric_type.value == "sum"
    return MetricResult(
        metric_key=metric.metric_key,
        metric_type=metric.metric_type.value,
        role=metric.role.value,
        variants=_variant_stats_list(metric, request, continuous),
        recommendation=Recommendation(action="insufficient_data", message=message),
    )


def _run_test(
    metric: MetricInput,
    request: AnalysisRequest,
    control: VariantInput,
    treatment: VariantInput,
) -> FrequentistTestResult:
    """Pick the right test for the metric type and run it on real stats."""
    control_stats = _stats_for(metric, control.variant_key)
    treatment_stats = _stats_for(metric, treatment.variant_key)

    if metric.metric_type.value == "sum":
        c_mean, c_std = _mean_and_std(control_stats)
        t_mean, t_std = _mean_and_std(treatment_stats)
        return welchs_t_test(
            c_mean, c_std, control_stats.sample_size,
            t_mean, t_std, treatment_stats.sample_size,
            request.config.significance_level,
        )

    return z_test_proportions(
        control_stats.conversions, control_stats.sample_size,
        treatment_stats.conversions, treatment_stats.sample_size,
        request.config.significance_level,
    )


def _analyze_metric(metric: MetricInput, request: AnalysisRequest) -> MetricResult:
    """Run frequentist analysis for a metric on the caller-provided counts."""
    if metric.metric_type in (MetricType.RATIO, MetricType.FUNNEL):
        # No test implemented for these: the proportion fallback would
        # misstate their variance (ratio denominators are not the
        # assignment unit), so fail visibly instead of silently.
        return _insufficient(
            metric,
            request,
            f"Metric type '{metric.metric_type.value}' is not yet supported.",
        )

    control = next((v for v in request.variants if v.is_control), None)
    treatment = next((v for v in request.variants if not v.is_control), None)

    if not control or not treatment:
        return _insufficient(
            metric, request, "Need at least one control and one treatment variant."
        )

    control_stats = _stats_for(metric, control.variant_key)
    treatment_stats = _stats_for(metric, treatment.variant_key)
    control_n = control_stats.sample_size
    treatment_n = treatment_stats.sample_size

    if control_n == 0 or treatment_n == 0:
        return _insufficient(
            metric, request, "No assignment data recorded yet for one or both variants."
        )

    continuous = metric.metric_type.value == "sum"
    freq_result = _run_test(metric, request, control, treatment)
    variants = _variant_stats_list(metric, request, continuous)

    baseline_rate = control_stats.conversions / control_n
    sample_size_result = None
    # The proportions-based sample-size formula doesn't apply to continuous
    # (sum-type) metrics — leave it unset there rather than misjudging
    # sufficiency from an irrelevant conversion rate.
    if not continuous and 0 < baseline_rate < 1:
        ss_calc = sample_size_proportions(
            baseline_rate=baseline_rate,
            minimum_detectable_effect=0.02,
            significance_level=request.config.significance_level,
            power=request.config.power,
        )
        sample_size_result = SampleSizeCalc(
            minimum_required=ss_calc["sample_size_per_variant"],
            current_total=control_n + treatment_n,
            is_sufficient=(control_n + treatment_n) >= ss_calc["total_sample_size"],
            baseline_rate=baseline_rate,
            minimum_detectable_effect=0.02,
            power=request.config.power,
            significance_level=request.config.significance_level,
        )

    # Days-to-significance projection (Roadmap #4): primary metrics only,
    # and only when the caller supplied a positive exposure rate — omitting
    # exposure_rate_per_day must leave the response byte-identical to today.
    projection = None
    raw_exposure_rate = request.config.exposure_rate_per_day
    if metric.role == MetricRole.PRIMARY and raw_exposure_rate is not None and raw_exposure_rate > 0:
        minimum_required = sample_size_result.minimum_required if sample_size_result else None
        exposure_rate = raw_exposure_rate
        variant_count = request.config.variant_count
        # exposure_rate_per_day is measured by the Elixir side across the
        # *whole* experiment, but this analysis only ever compares one
        # control/treatment pair (num_variants=2 below). For a 3+-arm
        # experiment, using the experiment-wide rate directly overstates how
        # much traffic lands in this pair, biasing days_remaining
        # optimistically. Scale it down to the pair's even share of traffic
        # (assumes an even split across arms — the only assumption available
        # without per-arm rates). Omitting variant_count, or a value < 2,
        # leaves the rate unscaled, matching today's behavior exactly.
        if variant_count is not None and variant_count >= 2:
            exposure_rate = exposure_rate * 2 / variant_count
        proj = project_days_to_significance(
            minimum_required_per_variant=minimum_required,
            current_total=control_n + treatment_n,
            # This analysis only ever compares one control to one treatment.
            num_variants=2,
            exposure_rate_per_day=exposure_rate,
        )
        projection = ProjectionResult(**proj)

    # Sequential analysis if configured and a sample-size target exists
    sequential = None
    if request.config.sequential_analysis and sample_size_result:
        total_required = sample_size_result.minimum_required * 2
        info_fraction = min(1.0, (control_n + treatment_n) / total_required)
        se = (freq_result.confidence_interval[1] - freq_result.confidence_interval[0]) / 3.92
        z_stat = freq_result.effect_size_absolute / se if se > 0 else 0
        seq_result = evaluate_sequential(
            z_stat, info_fraction,
            request.config.significance_level,
            request.config.spending_function or "obrien_fleming",
        )
        sequential = SequentialResult(**seq_result)

    if continuous:
        if freq_result.is_significant:
            recommendation = Recommendation(
                action="significant_winner",
                winning_variant=treatment.variant_key,
                confidence="high",
                message=(
                    f"Treatment shows a statistically significant difference "
                    f"(p={freq_result.p_value:.4f})."
                ),
            )
        else:
            recommendation = Recommendation(
                action="no_significant_difference",
                message=(
                    f"No statistically significant difference detected "
                    f"(p={freq_result.p_value:.4f}). Sample-size sufficiency is not "
                    "estimated for continuous metrics."
                ),
            )
    elif sample_size_result is None:
        recommendation = Recommendation(
            action="insufficient_data",
            message="No conversions recorded for the control variant yet. Continue running.",
        )
    elif not sample_size_result.is_sufficient:
        recommendation = Recommendation(
            action="insufficient_data",
            message=(
                f"Only {sample_size_result.current_total} of "
                f"{sample_size_result.minimum_required * 2} required samples collected. "
                "Continue running."
            ),
        )
    elif freq_result.is_significant:
        recommendation = Recommendation(
            action="significant_winner",
            winning_variant=treatment.variant_key,
            confidence="high",
            message=(
                f"Treatment shows a statistically significant difference "
                f"(p={freq_result.p_value:.4f})."
            ),
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
        projection=projection,
    )


def _analyze_guardrail(metric: MetricInput, request: AnalysisRequest) -> MetricResult:
    """Evaluate a guardrail metric against real counts.

    `current_value` is the treatment's relative effect vs control, matching
    the semantics ExperimentHub.Metrics.GuardrailEvaluator applies on the
    Elixir side ("above": effect > threshold breaches; "below": effect <
    -threshold breaches).
    """
    threshold = metric.guardrail_threshold or 0.05
    # Default matches the Elixir evaluator's fallback (guardrail_evaluator.ex).
    direction = metric.guardrail_direction.value if metric.guardrail_direction else "below"

    if metric.metric_type in (MetricType.RATIO, MetricType.FUNNEL):
        # Same rejection as _analyze_metric: the proportion fallback would
        # misstate variance, and here a false breach could gate a rollout.
        return MetricResult(
            metric_key=metric.metric_key,
            metric_type=metric.metric_type.value,
            role="guardrail",
            variants=_variant_stats_list(metric, request, False),
            guardrail_status=GuardrailStatus(
                threshold=threshold,
                direction=direction,
                current_value=0.0,
                is_breached=False,
            ),
            recommendation=Recommendation(
                action="insufficient_data",
                message=f"Metric type '{metric.metric_type.value}' is not yet supported.",
            ),
        )

    control = next((v for v in request.variants if v.is_control), None)
    treatment = next((v for v in request.variants if not v.is_control), None)

    if not control or not treatment:
        return _insufficient(
            metric, request, "Need at least one control and one treatment variant."
        )

    control_stats = _stats_for(metric, control.variant_key)
    treatment_stats = _stats_for(metric, treatment.variant_key)

    if control_stats.sample_size == 0 or treatment_stats.sample_size == 0:
        return MetricResult(
            metric_key=metric.metric_key,
            metric_type=metric.metric_type.value,
            role="guardrail",
            variants=_variant_stats_list(metric, request, False),
            guardrail_status=GuardrailStatus(
                threshold=threshold,
                direction=direction,
                current_value=0.0,
                is_breached=False,
            ),
            recommendation=Recommendation(
                action="insufficient_data",
                message="No assignment data recorded yet for one or both variants.",
            ),
        )

    freq_result = _run_test(metric, request, control, treatment)
    current_value = freq_result.effect_size_relative

    if direction == "above":
        is_breached = current_value > threshold
    else:
        is_breached = current_value < -threshold

    return MetricResult(
        metric_key=metric.metric_key,
        metric_type=metric.metric_type.value,
        role="guardrail",
        variants=_variant_stats_list(metric, request, metric.metric_type.value == "sum"),
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
        guardrail_status=GuardrailStatus(
            threshold=threshold,
            direction=direction,
            current_value=current_value,
            is_breached=is_breached,
        ),
    )
