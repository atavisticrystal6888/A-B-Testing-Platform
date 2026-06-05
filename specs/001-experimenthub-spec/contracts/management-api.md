# Management API Contract

**Version**: 1.0.0 | **Service**: Management API (Elixir/Phoenix)
**Base URL**: `https://{host}/api/v1`
**Auth**: Bearer JWT (dashboard) or API Key via `X-API-Key` (programmatic)

---

## Experiments

### POST /api/v1/experiments

Create a new experiment (FR-001).

**Required Role**: `editor`, `admin`

```json
// Request
{
  "key": "checkout-button-color",
  "name": "Checkout Button Color Test",
  "hypothesis": "Green checkout button increases conversions by 5%",
  "description": "Testing whether a green CTA button outperforms the current blue button",
  "feature_tag": "checkout-page",
  "variants": [
    { "key": "control", "name": "Blue Button", "is_control": true, "traffic_allocation": 5000 },
    { "key": "treatment", "name": "Green Button", "is_control": false, "traffic_allocation": 5000 }
  ],
  "primary_metric_key": "checkout_conversion",
  "secondary_metric_keys": ["revenue_per_user"],
  "scheduled_start_at": null,
  "scheduled_end_at": null,
  "experiment_group_id": null
}

// Response — 201 Created
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "key": "checkout-button-color",
  "name": "Checkout Button Color Test",
  "hypothesis": "Green checkout button increases conversions by 5%",
  "feature_tag": "checkout-page",
  "status": "draft",
  "variants": [...],
  "metrics": [...],
  "warnings": [
    {
      "type": "experiment_overlap",
      "message": "Running experiment 'checkout-flow-redesign' targets the same feature tag 'checkout-page'. Consider placing experiments in a mutual exclusion group.",
      "overlapping_experiments": [
        { "id": "...", "key": "checkout-flow-redesign", "name": "Checkout Flow Redesign", "status": "running" }
      ]
    }
  ],
  "version": 1,
  "inserted_at": "2026-04-01T12:00:00Z",
  "updated_at": "2026-04-01T12:00:00Z"
}
```

### GET /api/v1/experiments

List experiments with filtering (FR-054).

**Required Role**: `viewer`, `editor`, `admin`

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| status | string | — | Filter by status: draft, running, paused, concluded |
| archived | boolean | false | Include archived experiments |
| search | string | — | Search by name or key |
| sort | string | inserted_at | Sort field: inserted_at, name, status, started_at |
| order | string | desc | Sort order: asc, desc |
| page | integer | 1 | Page number |
| page_size | integer | 20 | Items per page (max 100) |

```json
// Response — 200 OK
{
  "data": [
    {
      "id": "550e8400-...",
      "key": "checkout-button-color",
      "name": "Checkout Button Color Test",
      "status": "running",
      "variant_count": 2,
      "started_at": "2026-04-01T12:00:00Z",
      "inserted_at": "2026-04-01T11:50:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 20,
    "total_count": 45,
    "total_pages": 3
  }
}
```

### GET /api/v1/experiments/:id

Get experiment details.

**Required Role**: `viewer`, `editor`, `admin`

```json
// Response — 200 OK
{
  "id": "550e8400-...",
  "key": "checkout-button-color",
  "name": "Checkout Button Color Test",
  "hypothesis": "Green checkout button increases conversions by 5%",
  "description": "...",
  "status": "running",
  "variants": [
    { "id": "...", "key": "control", "name": "Blue Button", "is_control": true, "traffic_allocation": 5000 },
    { "id": "...", "key": "treatment", "name": "Green Button", "is_control": false, "traffic_allocation": 5000 }
  ],
  "metrics": [
    { "id": "...", "key": "checkout_conversion", "name": "Checkout Conversion", "role": "primary" }
  ],
  "targeting_rules": [],
  "experiment_group": null,
  "conclusion_decision": null,
  "conclusion_rationale": null,
  "scheduled_start_at": null,
  "scheduled_end_at": null,
  "started_at": "2026-04-01T12:00:00Z",
  "concluded_at": null,
  "version": 2,
  "inserted_at": "2026-04-01T11:50:00Z",
  "updated_at": "2026-04-01T12:00:00Z"
}
```

### PUT /api/v1/experiments/:id

Update experiment (FR-006). Requires version for optimistic locking.

**Required Role**: `editor`, `admin`

```json
// Request
{
  "name": "Updated Name",
  "description": "Updated description",
  "version": 2
}

// Response — 200 OK (updated experiment)
// Response — 409 Conflict (version mismatch)
{
  "error": "conflict",
  "message": "Experiment was modified by another user. Please refresh and try again.",
  "current_version": 3
}
```

### POST /api/v1/experiments/:id/start

Transition experiment from draft → running (FR-002).

**Required Role**: `editor`, `admin`

```json
// Response — 200 OK
{ "id": "...", "status": "running", "started_at": "2026-04-01T12:00:00Z", "version": 3 }

// Response — 422 Unprocessable Entity
{
  "error": "invalid_transition",
  "message": "Cannot start experiment: missing primary metric",
  "violations": ["primary_metric_required"]
}
```

### POST /api/v1/experiments/:id/pause

Transition running → paused (FR-002).

**Required Role**: `editor`, `admin`

```json
// Request (optional)
{ "reason": "Investigating unexpected metric movement" }

// Response — 200 OK
{ "id": "...", "status": "paused", "version": 4 }
```

### POST /api/v1/experiments/:id/resume

Transition paused → running (FR-002).

**Required Role**: `editor`, `admin`

```json
// Request (optional)
{ "reason": "Guardrail breach investigated and resolved" }

// Response — 200 OK
{ "id": "...", "status": "running", "version": 5 }

// Response — 422 Unprocessable Entity
{
  "error": "invalid_transition",
  "message": "Cannot resume experiment: experiment is not paused",
  "violations": ["experiment_not_paused"]
}
```

### POST /api/v1/experiments/:id/conclude

Transition running/paused → concluded (FR-007).

**Required Role**: `editor`, `admin`

```json
// Request
{
  "decision": "ship_variant",
  "winning_variant_id": "660e8400-e29b-41d4-a716-446655440001",
  "rationale": "12% conversion vs 10% control, p=0.003, statistically significant"
}

// Response — 200 OK
{
  "id": "...",
  "status": "concluded",
  "conclusion_decision": "ship_variant",
  "conclusion_rationale": "...",
  "concluded_at": "2026-04-15T09:00:00Z",
  "version": 5
}
```

---

## Metrics

### POST /api/v1/metric-definitions

Create a metric definition (FR-060).

**Required Role**: `editor`, `admin`

```json
// Request
{
  "key": "checkout_conversion",
  "name": "Checkout Conversion Rate",
  "metric_type": "count",
  "definition": {
    "event_name": "checkout_completed",
    "event_type": "conversion"
  }
}

// Response — 201 Created
{ "id": "...", "key": "checkout_conversion", ... }
```

### GET /api/v1/metric-definitions

List metric definitions. **Role**: `viewer+`

### GET /api/v1/metric-definitions/:id

Get metric definition. **Role**: `viewer+`

### PUT /api/v1/metric-definitions/:id

Update metric definition. **Role**: `editor+`

### DELETE /api/v1/metric-definitions/:id

Delete metric definition (only if not attached to any experiment). **Role**: `admin`

---

## Experiment Metrics

### POST /api/v1/experiments/:experiment_id/metrics

Attach a metric to an experiment (FR-062).

**Required Role**: `editor`, `admin`

```json
// Request
{
  "metric_definition_id": "...",
  "role": "guardrail",
  "guardrail_threshold": 0.05,
  "guardrail_direction": "above"
}
```

### DELETE /api/v1/experiments/:experiment_id/metrics/:id

Detach a metric from an experiment. **Role**: `editor+`

---

## Targeting Rules

### POST /api/v1/experiments/:experiment_id/targeting-rules

Add targeting rule (FR-031).

**Required Role**: `editor`, `admin`

```json
// Request
{
  "attribute": "country",
  "operator": "eq",
  "value": "US",
  "logic_group": 0
}
```

### GET /api/v1/experiments/:experiment_id/targeting-rules

List targeting rules. **Role**: `viewer+`

### DELETE /api/v1/experiments/:experiment_id/targeting-rules/:id

Remove targeting rule. **Role**: `editor+`

---

## Experiment Groups (Mutual Exclusion)

### POST /api/v1/experiment-groups

Create mutual exclusion group (FR-036).

**Required Role**: `editor`, `admin`

```json
{ "name": "Checkout Tests", "description": "Mutually exclusive checkout experiments" }
```

### GET /api/v1/experiment-groups

List groups. **Role**: `viewer+`

### GET /api/v1/experiment-groups/:id

Get group with member experiments. **Role**: `viewer+`

---

## Results & Export

### GET /api/v1/experiments/:id/results

Get experiment results (FR-056).

**Required Role**: `viewer`, `editor`, `admin`

```json
// Response — 200 OK
{
  "experiment_id": "...",
  "status": "running",
  "sample_sizes": { "control": 5000, "treatment": 5000 },
  "minimum_sample_size": 3842,
  "has_sufficient_data": true,
  "metrics": [
    {
      "metric_key": "checkout_conversion",
      "role": "primary",
      "variants": [
        {
          "variant_key": "control",
          "sample_size": 5000,
          "conversions": 500,
          "conversion_rate": 0.10
        },
        {
          "variant_key": "treatment",
          "sample_size": 5000,
          "conversions": 600,
          "conversion_rate": 0.12
        }
      ],
      "frequentist": {
        "p_value": 0.003,
        "confidence_interval": [0.005, 0.035],
        "effect_size": 0.02,
        "power": 0.89,
        "is_significant": true,
        "correction_method": null
      },
      "bayesian": {
        "probability_to_be_best": {
          "control": 0.05,
          "treatment": 0.95
        },
        "credible_interval": [0.006, 0.034],
        "expected_loss": {
          "control": 0.018,
          "treatment": 0.001
        }
      },
      "sequential": {
        "spending_function": "obrien_fleming",
        "information_fraction": 0.65,
        "can_reject": true,
        "adjusted_critical_value": 2.30,
        "observed_z_statistic": 2.98
      },
      "recommendation": "treatment is the winner with 95% confidence"
    }
  ],
  "computed_at": "2026-04-10T12:00:00Z",
  "daily_results": [
    {
      "date": "2026-04-01",
      "variants": [
        { "variant_key": "control", "sample_size": 500, "conversions": 48, "conversion_rate": 0.096 },
        { "variant_key": "treatment", "sample_size": 500, "conversions": 62, "conversion_rate": 0.124 }
      ]
    }
  ]
}
```

### GET /api/v1/experiments/:id/results/export

Export experiment results (FR-058).

**Required Role**: `viewer`, `editor`, `admin`

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| format | string | Yes | One of: `csv`, `json`, `xlsx` |

Response: File download with appropriate Content-Type header.

---

## Tenants (Admin Only)

### POST /api/v1/tenants

Create tenant. **Role**: platform superadmin

```json
{ "name": "Acme Corp", "slug": "acme-corp", "settings": { "rate_limit_per_minute": 10000 } }
```

### GET /api/v1/tenants

List tenants. **Role**: platform superadmin

### GET /api/v1/tenants/:id

Get tenant. **Role**: `admin` (own tenant) or superadmin

### PUT /api/v1/tenants/:id

Update tenant. **Role**: `admin` (own tenant) or superadmin

---

## API Keys

### POST /api/v1/api-keys

Generate API key (FR-041).

**Required Role**: `admin`

```json
// Request
{ "name": "Production SDK Key", "expires_at": null }

// Response — 201 Created (key shown ONCE)
{
  "id": "...",
  "key": "eh_live_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "key_prefix": "eh_live_",
  "name": "Production SDK Key",
  "expires_at": null,
  "inserted_at": "2026-04-01T12:00:00Z"
}
```

### GET /api/v1/api-keys

List API keys (key not shown, only prefix). **Role**: `admin`

### DELETE /api/v1/api-keys/:id

Revoke API key. **Role**: `admin`

---

## Users

### POST /api/v1/users

Create user within tenant. **Role**: `admin`

```json
{ "email": "pm@acme.com", "password": "...", "role": "editor" }
```

### GET /api/v1/users

List users. **Role**: `admin`

### PUT /api/v1/users/:id

Update user role. **Role**: `admin`

### DELETE /api/v1/users/:id

Remove user from tenant. **Role**: `admin`

---

## Audit Log

### GET /api/v1/audit-logs

Query audit log (FR-069, FR-070).

**Required Role**: `viewer`, `editor`, `admin`

| Param | Type | Description |
|-------|------|-------------|
| resource_type | string | Filter: experiment, feature_flag, api_key, user |
| resource_id | UUID | Filter: specific resource |
| action | string | Filter: experiment.created, experiment.started, etc. |
| actor_id | UUID | Filter: specific user |
| from | ISO 8601 | Start date |
| to | ISO 8601 | End date |
| page | integer | Page number (default 1) |
| page_size | integer | Items per page (default 50, max 200) |

```json
// Response — 200 OK
{
  "data": [
    {
      "id": "...",
      "actor": { "id": "...", "email": "pm@acme.com", "type": "user" },
      "action": "experiment.started",
      "resource_type": "experiment",
      "resource_id": "550e8400-...",
      "changes": {
        "status": { "from": "draft", "to": "running" }
      },
      "reason": null,
      "inserted_at": "2026-04-01T12:00:00Z"
    }
  ],
  "meta": { "page": 1, "page_size": 50, "total_count": 127 }
}
```

---

## Feature Flags

### POST /api/v1/feature-flags

Create feature flag (FR-047). **Role**: `editor+`

```json
{
  "key": "new-checkout-flow",
  "name": "New Checkout Flow",
  "description": "Redesigned checkout experience",
  "enabled": false,
  "rollout_percentage": 0
}
```

### GET /api/v1/feature-flags

List flags. **Role**: `viewer+`

### GET /api/v1/feature-flags/:id

Get flag. **Role**: `viewer+`

### PUT /api/v1/feature-flags/:id

Update flag (enable/disable, change rollout %). **Role**: `editor+`

```json
{ "enabled": true, "rollout_percentage": 2500, "version": 1 }
```

### DELETE /api/v1/feature-flags/:id

Delete flag. **Role**: `admin`

---

## Platform Analytics

### GET /api/v1/analytics/platform

Platform-wide analytics (FR-059). **Role**: `viewer+`

```json
// Response — 200 OK
{
  "active_experiments": 8,
  "concluded_this_month": 4,
  "draft_experiments": 3,
  "average_experiment_duration_days": 14.5,
  "total_events_today": 150000,
  "power_distribution": {
    "below_80": 2,
    "80_to_90": 3,
    "above_90": 3
  }
}
```

---

## Common Response Headers

All responses include:

| Header | Description |
|--------|-------------|
| X-Request-Id | Unique request identifier for tracing |
| X-RateLimit-Limit | Maximum requests per window |
| X-RateLimit-Remaining | Remaining requests in current window |
| X-RateLimit-Reset | Unix timestamp when window resets |

## Common Error Format

```json
{
  "error": "error_code",
  "message": "Human-readable description",
  "details": []
}
```

---

## Authentication

### POST /api/v1/auth/login

Authenticate a dashboard user and receive a JWT token.

**Auth**: None (public endpoint)

```json
// Request
{
  "email": "pm@acme.com",
  "password": "..."
}

// Response — 200 OK
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "...",
    "email": "pm@acme.com",
    "role": "editor",
    "tenant_id": "...",
    "tenant_name": "Acme Corp"
  },
  "expires_at": "2026-04-02T12:00:00Z"
}

// Response — 401 Unauthorized
{
  "error": "invalid_credentials",
  "message": "Invalid email or password"
}
```

### POST /api/v1/auth/refresh

Refresh an expiring JWT token.

**Auth**: Bearer JWT

```json
// Response — 200 OK
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "expires_at": "2026-04-02T12:00:00Z"
}
```

---

## GDPR Compliance

### POST /api/v1/gdpr/anonymize

Anonymize all data for a specific participant user_id (FR-072).

**Required Role**: `admin`

```json
// Request
{
  "user_id": "participant_abc123"
}

// Response — 202 Accepted (background processing for large datasets)
{
  "id": "anonymization-request-uuid",
  "status": "processing",
  "target_user_id": "participant_abc123",
  "message": "Anonymization request accepted. Use GET /api/v1/gdpr/anonymization-requests/:id to check progress."
}

// Response — 200 OK (immediate processing for small datasets)
{
  "id": "anonymization-request-uuid",
  "status": "completed",
  "target_user_id": "participant_abc123",
  "pseudonymized_user_id": "a1b2c3d4e5f6...",
  "records_anonymized": {
    "assignments": 3,
    "experiment_events_raw": 142,
    "audit_logs": 5
  }
}
```

### GET /api/v1/gdpr/anonymization-requests/:id

Check the status of an anonymization request.

**Required Role**: `admin`

```json
// Response — 200 OK
{
  "id": "anonymization-request-uuid",
  "status": "completed",
  "target_user_id": "participant_abc123",
  "pseudonymized_user_id": "a1b2c3d4e5f6...",
  "records_anonymized": {
    "assignments": 3,
    "experiment_events_raw": 142,
    "audit_logs": 5
  },
  "started_at": "2026-04-01T12:00:00Z",
  "completed_at": "2026-04-01T12:00:45Z"
}
```

### DELETE /api/v1/tenants/:id

Initiate tenant offboarding with 72-hour soft-delete grace period (FR-073).

**Required Role**: platform superadmin

```json
// Response — 202 Accepted
{
  "id": "...",
  "status": "deletion_scheduled",
  "deletion_scheduled_at": "2026-04-04T12:00:00Z",
  "message": "Tenant deletion scheduled. All API keys are immediately disabled. Permanent deletion occurs in 72 hours. Call DELETE /api/v1/tenants/:id/cancel to abort."
}
```

### DELETE /api/v1/tenants/:id/cancel

Cancel a pending tenant deletion during the 72-hour grace period.

**Required Role**: platform superadmin

```json
// Response — 200 OK
{
  "id": "...",
  "status": "active",
  "message": "Tenant deletion cancelled. API keys have been re-enabled."
}
```
