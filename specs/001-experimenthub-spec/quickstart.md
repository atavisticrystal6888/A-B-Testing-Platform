# Quickstart: ExperimentHub Validation Scenarios

**Branch**: `001-experimenthub-spec` | **Date**: 2026-04-01

These scenarios validate the core ExperimentHub functionality end-to-end. Execute them in order after deployment to confirm the system works correctly.

---

## Prerequisites

- Docker Compose environment running (PostgreSQL, Kafka, Redis, all services)
- A tenant created with an API key
- At least one metric definition ("checkout_conversion") exists

```bash
# Start all services
docker compose up -d

# Verify all services are healthy
curl http://localhost:4000/health  # Management API
curl http://localhost:8000/stats/v1/health  # Statistical Engine
```

---

## Scenario 1: Full Experiment Lifecycle (Happy Path)

**Maps to**: US1 → US2 → US3 → US4 → US5 → US6
**Constitution**: Articles I (service boundaries), II (statistical rigor), V (event sourcing)

### Step 1: Create Experiment

```bash
curl -X POST http://localhost:4000/api/v1/experiments \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "checkout-button-color",
    "name": "Checkout Button Color Test",
    "hypothesis": "Green checkout button increases conversions by 5%",
    "feature_tag": "checkout-page",
    "variants": [
      {"key": "control", "name": "Blue Button", "is_control": true, "traffic_allocation": 5000},
      {"key": "treatment", "name": "Green Button", "is_control": false, "traffic_allocation": 5000}
    ],
    "primary_metric_key": "checkout_conversion"
  }'
```

**Expected**: 201 Created, `status: "draft"`, `version: 1`

### Step 2: Start Experiment

```bash
curl -X POST http://localhost:4000/api/v1/experiments/$EXPERIMENT_ID/start \
  -H "X-API-Key: $API_KEY"
```

**Expected**: 200 OK, `status: "running"`, `started_at` is set

### Step 3: Assign Users

```bash
# Assign a single user
curl -X POST http://localhost:4000/v1/assign \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user_001", "experiment_key": "checkout-button-color"}'
```

**Expected**: 200 OK, returns `variant_key` ("control" or "treatment"). Same user always returns same variant.

### Step 4: Send Events

```bash
# Send a batch of conversion events
curl -X POST http://localhost:4000/v1/events/batch \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "events": [
      {"experiment_id": "'$EXPERIMENT_ID'", "user_id": "user_001", "event_type": "conversion", "event_name": "checkout_completed", "value": 1, "timestamp": "2026-04-01T12:05:00Z", "idempotency_key": "evt_user001_001"},
      {"experiment_id": "'$EXPERIMENT_ID'", "user_id": "user_002", "event_type": "conversion", "event_name": "checkout_completed", "value": 1, "timestamp": "2026-04-01T12:06:00Z", "idempotency_key": "evt_user002_001"}
    ]
  }'
```

**Expected**: 202 Accepted, `accepted: 2`

### Step 5: View Results

Wait for data pipeline aggregation (~60 seconds), then:

```bash
curl http://localhost:4000/api/v1/experiments/$EXPERIMENT_ID/results \
  -H "X-API-Key: $API_KEY"
```

**Expected**: 200 OK with per-variant conversion rates, frequentist p-value, Bayesian probability-to-be-best.

### Step 6: Conclude Experiment

```bash
curl -X POST http://localhost:4000/api/v1/experiments/$EXPERIMENT_ID/conclude \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "decision": "ship_variant",
    "winning_variant_id": "'$TREATMENT_VARIANT_ID'",
    "rationale": "12% conversion vs 10% control, statistically significant"
  }'
```

**Expected**: 200 OK, `status: "concluded"`, `conclusion_decision: "ship_variant"`

### Verification

```bash
# Verify audit trail
curl "http://localhost:4000/api/v1/audit-logs?resource_type=experiment&resource_id=$EXPERIMENT_ID" \
  -H "X-API-Key: $API_KEY"
```

**Expected**: Audit entries for: `experiment.created`, `experiment.started`, `experiment.concluded`

---

## Scenario 2: Assignment Determinism

**Maps to**: FR-009, FR-010 (Article IV)

### Test: Same user always gets same variant

```bash
# Call assignment 100 times for the same user
for i in $(seq 1 100); do
  curl -s -X POST http://localhost:4000/v1/assign \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"user_id": "determinism_test_user", "experiment_key": "checkout-button-color"}' \
    | jq -r '.variant_key'
done | sort | uniq -c
```

**Expected**: All 100 calls return the same variant. Output shows `100 treatment` (or `100 control`).

### Test: Uniform distribution

```bash
# Assign 10,000 unique users and check distribution
for i in $(seq 1 10000); do
  curl -s -X POST http://localhost:4000/v1/assign \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"dist_user_$i\", \"experiment_key\": \"checkout-button-color\"}" \
    | jq -r '.variant_key'
done | sort | uniq -c
```

**Expected**: ~5000 control, ~5000 treatment (within ±1%, i.e., 4900-5100 each). Chi-squared p > 0.05.

---

## Scenario 3: Statistical Accuracy vs scipy Reference

**Maps to**: SC-003, FR-030 (Article II)

### Test dataset: Known conversion rates

```python
# Reference computation (scipy)
from scipy.stats import proportions_ztest
import numpy as np

# 5000 users per variant, 10% vs 12% conversion
count = np.array([500, 600])
nobs = np.array([5000, 5000])
z_stat, p_value = proportions_ztest(count, nobs, alternative='two-sided')
print(f"p-value: {p_value:.6f}")  # Expected: ~0.003 (exact value depends on method)
```

### Validate ExperimentHub matches

1. Ingest exactly 5000 events per variant: 500 conversions for control, 600 for treatment.
2. Run statistical analysis via API.
3. Compare p-value, confidence interval, and effect size against scipy reference.

**Expected**: All values match within 0.1% margin (FR-030).

---

## Scenario 4: Multi-Tenant Isolation

**Maps to**: SC-006, FR-039 (Article VIII)

### Setup: Two tenants with separate API keys

```bash
# Create tenant A experiment
curl -X POST http://localhost:4000/api/v1/experiments \
  -H "X-API-Key: $TENANT_A_KEY" \
  -d '{"key": "tenant-a-experiment", "name": "Tenant A Test", ...}'

# Create tenant B experiment
curl -X POST http://localhost:4000/api/v1/experiments \
  -H "X-API-Key: $TENANT_B_KEY" \
  -d '{"key": "tenant-b-experiment", "name": "Tenant B Test", ...}'
```

### Test: Cross-tenant isolation

```bash
# Tenant A lists experiments — should NOT see tenant B's experiment
curl http://localhost:4000/api/v1/experiments \
  -H "X-API-Key: $TENANT_A_KEY" | jq '.data[].key'
# Expected: ["tenant-a-experiment"]

# Tenant B lists experiments — should NOT see tenant A's experiment
curl http://localhost:4000/api/v1/experiments \
  -H "X-API-Key: $TENANT_B_KEY" | jq '.data[].key'
# Expected: ["tenant-b-experiment"]

# Tenant A tries to access tenant B's experiment by ID — should fail
curl http://localhost:4000/api/v1/experiments/$TENANT_B_EXPERIMENT_ID \
  -H "X-API-Key: $TENANT_A_KEY"
# Expected: 404 Not Found (RLS prevents access)
```

---

## Scenario 5: Assignment Load Test

**Maps to**: NFR-001 (Article VI)

### k6 Load Test Script

```javascript
// k6/assignment_load.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    assignment_load: {
      executor: 'constant-arrival-rate',
      rate: 10000,        // 10,000 requests per second
      timeUnit: '1s',
      duration: '60s',    // Run for 1 minute
      preAllocatedVUs: 200,
      maxVUs: 500,
    },
  },
  thresholds: {
    http_req_duration: ['p(99)<5'],  // p99 < 5ms
  },
};

export default function () {
  const userId = `user_${__VU}_${__ITER}`;
  const payload = JSON.stringify({
    user_id: userId,
    experiment_key: 'checkout-button-color',
  });

  const res = http.post('http://localhost:4000/v1/assign', payload, {
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': __ENV.API_KEY,
    },
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
    'has variant_key': (r) => JSON.parse(r.body).variant_key !== undefined,
  });
}
```

### Run

```bash
k6 run --env API_KEY=$API_KEY k6/assignment_load.js
```

**Expected**:
- p99 latency < 5ms
- 0% error rate
- 10,000 requests/second sustained for 60 seconds

---

## Scenario 6: GDPR Anonymization

**Maps to**: FR-072, FR-073 (Article VIII, NFR-007)

### Test: Anonymize a participant's data

```bash
# First, assign a user and send events (from Scenario 1)
# Then request anonymization
curl -X POST http://localhost:4000/api/v1/gdpr/anonymize \
  -H "Authorization: Bearer $ADMIN_JWT" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user_001"}'
```

**Expected**: 200 OK (or 202 Accepted for large datasets) with `records_anonymized` counts.

### Verify anonymization is complete

```bash
# Check anonymization request status (if 202 was returned)
curl http://localhost:4000/api/v1/gdpr/anonymization-requests/$REQUEST_ID \
  -H "Authorization: Bearer $ADMIN_JWT"
```

**Expected**: `status: "completed"`, `records_anonymized` shows counts per table.

### Verify data is pseudonymized

```bash
# Query events — original user_id should be replaced with pseudonym
curl "http://localhost:4000/api/v1/audit-logs?resource_type=gdpr" \
  -H "Authorization: Bearer $ADMIN_JWT"
```

**Expected**: Audit entry for anonymization request with pseudonymized user_id. Original user_id no longer appears in assignments, events, or audit logs.
