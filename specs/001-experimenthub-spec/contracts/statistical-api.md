# Statistical Engine API Contract

**Version**: 1.0.0 | **Service**: Statistical Engine (Python/FastAPI)
**Base URL**: `https://{host}/stats/v1`
**Auth**: Internal service-to-service auth via shared secret in `X-Internal-Key` header.
**Note**: This API is NOT exposed to external clients. It is consumed only by the Management API.

---

## POST /stats/v1/analyze/{experiment_id}

Run full statistical analysis on an experiment (FR-022 through FR-030).

### Request

```json
{
  "tenant_id": "110e8400-e29b-41d4-a716-446655440000",
  "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
  "metrics": [
    {
      "metric_definition_id": "990e8400-e29b-41d4-a716-446655440020",
      "metric_key": "checkout_conversion",
      "metric_type": "count",
      "role": "primary"
    },
    {
      "metric_definition_id": "990e8400-e29b-41d4-a716-446655440021",
      "metric_key": "error_rate",
      "metric_type": "count",
      "role": "guardrail",
      "guardrail_threshold": 0.05,
      "guardrail_direction": "above"
    }
  ],
  "variants": [
    { "variant_id": "660e8400-...", "variant_key": "control", "is_control": true },
    { "variant_id": "660e8400-...", "variant_key": "treatment", "is_control": false }
  ],
  "config": {
    "significance_level": 0.05,
    "power": 0.80,
    "correction_method": "holm",
    "sequential_analysis": true,
    "spending_function": "obrien_fleming",
    "analysis_types": ["frequentist", "bayesian"]
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| tenant_id | UUID | Yes | Tenant scope for data access |
| experiment_id | UUID | Yes | Experiment to analyze |
| metrics | array | Yes | Metric definitions to analyze |
| variants | array | Yes | Variant definitions with control flag |
| config | object | No | Analysis configuration (defaults used if omitted) |

### Response — 200 OK

```json
{
  "experiment_id": "550e8400-...",
  "computed_at": "2026-04-10T12:00:00Z",
  "computation_time_ms": 245,
  "metrics": [
    {
      "metric_key": "checkout_conversion",
      "metric_type": "count",
      "role": "primary",
      "variants": [
        {
          "variant_key": "control",
          "sample_size": 5000,
          "conversions": 500,
          "conversion_rate": 0.10,
          "mean": 0.10,
          "std_dev": 0.30
        },
        {
          "variant_key": "treatment",
          "sample_size": 5000,
          "conversions": 600,
          "conversion_rate": 0.12,
          "mean": 0.12,
          "std_dev": 0.325
        }
      ],
      "frequentist": {
        "test_method": "z_test_proportions",
        "p_value": 0.003,
        "adjusted_p_value": 0.003,
        "correction_method": null,
        "confidence_level": 0.95,
        "confidence_interval": {
          "lower": 0.005,
          "upper": 0.035,
          "point_estimate": 0.02
        },
        "effect_size": {
          "absolute": 0.02,
          "relative": 0.20,
          "cohens_h": 0.065
        },
        "power_achieved": 0.89,
        "is_significant": true
      },
      "bayesian": {
        "model": "beta_binomial",
        "prior": { "alpha": 1, "beta": 1 },
        "posteriors": {
          "control": { "alpha": 501, "beta": 4501 },
          "treatment": { "alpha": 601, "beta": 4401 }
        },
        "probability_to_be_best": {
          "control": 0.05,
          "treatment": 0.95
        },
        "credible_interval": {
          "level": 0.95,
          "lower": 0.006,
          "upper": 0.034,
          "point_estimate": 0.02
        },
        "expected_loss": {
          "control": 0.018,
          "treatment": 0.001
        }
      },
      "sequential": {
        "spending_function": "obrien_fleming",
        "information_fraction": 0.65,
        "nominal_alpha": 0.021,
        "adjusted_critical_value": 2.30,
        "observed_z_statistic": 2.98,
        "can_reject": true
      },
      "sample_size_calculation": {
        "minimum_required": 3842,
        "current_total": 10000,
        "is_sufficient": true,
        "baseline_rate": 0.10,
        "minimum_detectable_effect": 0.02,
        "power": 0.80,
        "significance_level": 0.05
      },
      "recommendation": {
        "action": "significant_winner",
        "winning_variant": "treatment",
        "confidence": "high",
        "message": "Treatment shows a statistically significant improvement of +2.0pp (p=0.003). Bayesian probability of being best: 95%."
      }
    },
    {
      "metric_key": "error_rate",
      "role": "guardrail",
      "guardrail_status": {
        "threshold": 0.05,
        "direction": "above",
        "current_value": 0.032,
        "is_breached": false
      }
    }
  ],
  "overall_status": "sufficient_data",
  "guardrail_breaches": []
}
```

### Response — 200 OK (insufficient data)

```json
{
  "experiment_id": "...",
  "metrics": [{
    "metric_key": "checkout_conversion",
    "frequentist": {
      "p_value": 0.18,
      "is_significant": false
    },
    "sample_size_calculation": {
      "minimum_required": 3842,
      "current_total": 800,
      "is_sufficient": false
    },
    "recommendation": {
      "action": "insufficient_data",
      "message": "Only 800 of 3842 required samples collected (21%). Continue running the experiment."
    }
  }],
  "overall_status": "insufficient_data"
}
```

### Response — 200 OK (guardrail breach)

```json
{
  "experiment_id": "...",
  "metrics": [{
    "metric_key": "error_rate",
    "role": "guardrail",
    "guardrail_status": {
      "threshold": 0.05,
      "direction": "above",
      "current_value": 0.067,
      "is_breached": true,
      "breach_magnitude": 0.017
    }
  }],
  "guardrail_breaches": [
    {
      "metric_key": "error_rate",
      "threshold": 0.05,
      "current_value": 0.067,
      "breach_magnitude": 0.017,
      "variant_key": "treatment",
      "recommendation": "Auto-pause recommended: error_rate (6.7%) exceeds threshold (5.0%) by 1.7pp"
    }
  ]
}
```

---

## GET /stats/v1/analyze/{experiment_id}/results

Get cached analysis results (most recent).

### Response — 200 OK

Same schema as POST response above, from the most recent computation.

### Response — 404 Not Found

```json
{
  "error": "no_results",
  "message": "No analysis results found for this experiment. Run POST /stats/v1/analyze/{experiment_id} first."
}
```

---

## POST /stats/v1/power

Calculate required sample size / statistical power (FR-028).

### Request

```json
{
  "baseline_rate": 0.10,
  "minimum_detectable_effect": 0.02,
  "significance_level": 0.05,
  "power": 0.80,
  "variant_count": 2,
  "test_type": "two_sided"
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| baseline_rate | float | Yes | — | Current conversion rate (0-1) |
| minimum_detectable_effect | float | Yes | — | Absolute effect to detect |
| significance_level | float | No | 0.05 | Alpha level |
| power | float | No | 0.80 | Statistical power (1 - beta) |
| variant_count | int | No | 2 | Number of variants (for correction) |
| test_type | string | No | two_sided | `one_sided` or `two_sided` |

### Response — 200 OK

```json
{
  "sample_size_per_variant": 3842,
  "total_sample_size": 7684,
  "parameters": {
    "baseline_rate": 0.10,
    "minimum_detectable_effect": 0.02,
    "treatment_rate": 0.12,
    "significance_level": 0.05,
    "power": 0.80,
    "variant_count": 2,
    "test_type": "two_sided",
    "correction_applied": false
  },
  "sensitivity_analysis": [
    { "mde": 0.01, "sample_per_variant": 14751 },
    { "mde": 0.02, "sample_per_variant": 3842 },
    { "mde": 0.03, "sample_per_variant": 1747 },
    { "mde": 0.05, "sample_per_variant": 651 }
  ]
}
```

---

## GET /stats/v1/health

Health check endpoint.

```json
// Response — 200 OK
{
  "status": "healthy",
  "version": "1.0.0",
  "dependencies": {
    "postgresql": "connected",
    "computation": "ready"
  },
  "uptime_seconds": 86400
}
```

---

## Performance Requirements

| Endpoint | p99 Latency | Notes |
|----------|-------------|-------|
| POST /stats/v1/analyze | < 30 sec | NFR-008. Scales with observation count. |
| GET /stats/v1/analyze/.../results | < 200ms | Cached result retrieval. |
| POST /stats/v1/power | < 500ms | Analytical computation. |

## Computation Audit Trail

Every analysis run produces a `statistical_analyses` record (see data-model.md) containing:
- `methodology`: Exact test used (e.g., "z_test_proportions")
- `parameters`: All configuration (alpha, prior, spending function)
- `results`: Full output (p-value, CI, posteriors)
- `sample_sizes`: Per-variant sample sizes at computation time

This satisfies Article II (Statistical Rigor) — every computation is auditable.
