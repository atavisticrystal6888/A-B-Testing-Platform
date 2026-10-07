# ExperimentHub Public API Reference

Base URL: `https://your-instance.example.com`

Authentication depends on the route family:

- Runtime routes (`/v1/assign`, `/v1/events`, `/api/v1/flags/evaluate`): send `X-API-Key: <key>`.
- Dashboard and management routes (`/api/v1/experiments`, ...): send `Authorization: Bearer <jwt>`.

---

## Authentication

### POST /auth/register
Create a new user account.

**Request Body:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "securePassword123",
    "first_name": "Jane",
    "last_name": "Doe"
  }
}
```

**Response:** `201 Created`
```json
{ "token": "eyJhbGciOi..." }
```

### POST /auth/login
Authenticate and receive a JWT token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Response:** `200 OK`
```json
{ "token": "eyJhbGciOi..." }
```

---

## Experiments

### GET /api/v1/experiments
List all experiments for the current tenant.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| status | string | Filter by status: draft, running, paused, concluded |
| page | integer | Page number (default: 1) |
| page_size | integer | Items per page (default: 20, max: 100) |

**Response:** `200 OK`
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Checkout Button Color",
      "hypothesis": "Blue buttons will increase conversions",
      "status": "running",
      "variants": [...],
      "inserted_at": "2024-01-15T10:00:00Z"
    }
  ],
  "meta": { "page": 1, "total": 42 }
}
```

### POST /api/v1/experiments
Create a new experiment.

**Request Body:**
```json
{
  "experiment": {
    "name": "Checkout Button Color",
    "hypothesis": "Blue buttons will increase conversions by 5%",
    "variants": [
      { "name": "control", "weight": 50 },
      { "name": "blue", "weight": 50 }
    ],
    "primary_metric": "conversion_rate",
    "traffic_percentage": 100,
    "targeting_rules": []
  }
}
```

**Response:** `201 Created`

### GET /api/v1/experiments/:id
Get experiment details.

### PUT /api/v1/experiments/:id
Update experiment configuration (draft only).

### POST /api/v1/experiments/:id/start
Start running the experiment.

### POST /api/v1/experiments/:id/pause
Pause a running experiment.

### POST /api/v1/experiments/:id/resume
Resume a paused experiment.

### POST /api/v1/experiments/:id/conclude
Conclude experiment with a decision.

**Request Body:**
```json
{
  "decision": "ship",
  "winning_variant_id": "variant-uuid",
  "notes": "Blue button showed 12% improvement in conversion rate"
}
```

---

## Assignments

Runtime routes, authenticated with `X-API-Key`.

### POST /v1/assign
Get a variant assignment for a user.

**Request Body:**
```json
{
  "user_id": "user-123",
  "experiment_key": "checkout-copy-demo",
  "attributes": { "platform": "web", "country": "US" }
}
```

**Response:** `200 OK`
```json
{
  "experiment_key": "checkout-copy-demo",
  "variant_key": "reassurance-copy",
  "variant_name": "Reassurance copy",
  "experiment_id": "uuid",
  "variant_id": "uuid",
  "is_control": false,
  "enrolled": true,
  "assigned_at": "2026-01-15T10:30:00Z"
}
```

When the experiment is not running or the user is not targeted, the control
variant is returned with `enrolled: false` and nothing is recorded.

### POST /v1/assign/batch
Assign a user to several experiments at once.

**Request Body:**
```json
{
  "user_id": "user-123",
  "experiment_keys": ["checkout-copy-demo", "unknown-key"],
  "attributes": { "platform": "web" }
}
```

**Response:** `200 OK`
```json
{
  "user_id": "user-123",
  "assignments": [
    { "experiment_key": "checkout-copy-demo", "experiment_id": "uuid", "variant_key": "control", "variant_id": "uuid", "is_control": true, "enrolled": true },
    { "experiment_key": "unknown-key", "error": "experiment_not_found" }
  ],
  "assigned_at": "2026-01-15T10:30:00Z"
}
```

---

## Events

Runtime routes, authenticated with `X-API-Key`. Events require a UUID
`experiment_id` and should carry `variant_id`: the rollup buckets by both.

### POST /v1/events
Track a single event.

**Request Body:**
```json
{
  "user_id": "user-123",
  "event_type": "revenue",
  "event_name": "order_completed",
  "experiment_id": "uuid",
  "variant_id": "uuid",
  "timestamp": "2026-01-15T10:30:00Z",
  "idempotency_key": "d1c1c2f0-5b0e-4a53-9a39-0d5b7f3a1e11",
  "value": 1299,
  "properties": { "currency": "INR" }
}
```

`event_type` is one of `conversion`, `metric`, `revenue`; `value` is required
for `metric` and `revenue` events.

**Response:** `202 Accepted`
```json
{ "status": "accepted", "event_id": "uuid", "received_at": "2026-01-15T10:30:01Z" }
```

### POST /v1/events/batch
Track multiple events (1 to 1000).

**Request Body:**
```json
{
  "events": [
    { "user_id": "u1", "event_type": "conversion", "event_name": "checkout_completed", "experiment_id": "uuid", "variant_id": "uuid", "timestamp": "2026-01-15T10:30:00Z", "idempotency_key": "key-1" }
  ]
}
```

**Response:** `202` (all accepted), `207` (partial) or `400` (all rejected):
```json
{
  "status": "accepted",
  "accepted": 1,
  "rejected": 0,
  "errors": []
}
```

`status` is `accepted`, `partial` or `rejected`; each entry in `errors`
identifies the failed event by its index.

---

## Results

### GET /experiments/:id/results
Get statistical analysis results.

**Response:** `200 OK`
```json
{
  "data": {
    "experiment_id": "uuid",
    "status": "significant",
    "variants": [
      {
        "variant_id": "control",
        "sample_size": 5000,
        "conversions": 500,
        "conversion_rate": 0.10,
        "ci_lower": 0.091,
        "ci_upper": 0.109
      },
      {
        "variant_id": "blue",
        "sample_size": 5000,
        "conversions": 600,
        "conversion_rate": 0.12,
        "ci_lower": 0.111,
        "ci_upper": 0.129,
        "p_value": 0.003,
        "is_significant": true,
        "relative_lift": 0.20
      }
    ],
    "recommendation": "ship_treatment"
  }
}
```

---

## Feature Flags

### POST /api/v1/flags/evaluate
Evaluate a feature flag. Authenticated with `X-API-Key`.

**Request Body:**
```json
{ "key": "checkout_reassurance", "context": { "user_id": "user-123" } }
```

**Response:** `200 OK`
```json
{ "key": "checkout_reassurance", "enabled": true }
```

### POST /api/v1/flags/evaluate/batch
Evaluate several flags with one context.

**Request Body:**
```json
{ "keys": ["checkout_reassurance", "dark-mode"], "context": { "user_id": "user-123" } }
```

**Response:** `200 OK`
```json
{ "data": [ { "key": "checkout_reassurance", "enabled": true }, { "key": "dark-mode", "enabled": false } ] }
```

### GET /feature-flags
List all feature flags.

### POST /feature-flags
Create a feature flag.

### PUT /feature-flags/:id
Update a feature flag.

---

## GDPR

### POST /gdpr/anonymize
Request user data anonymization.

**Request Body:**
```json
{ "user_id": "user-123" }
```

**Response:** `202 Accepted`

### GET /gdpr/export
Export user data (right of access).

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| user_id | string | User whose data to export |

**Response:** `200 OK` (JSON with all user data)

---

## Error Responses

All errors follow a consistent format:

```json
{
  "error": "not_found",
  "message": "Experiment not found",
  "status": 404
}
```

| Status | Error Code | Description |
|--------|-----------|-------------|
| 400 | bad_request | Invalid request body |
| 401 | unauthorized | Missing or invalid API key |
| 403 | forbidden | Insufficient permissions |
| 404 | not_found | Resource not found |
| 409 | conflict | State conflict (e.g., launching concluded experiment) |
| 422 | unprocessable_entity | Validation error |
| 429 | rate_limited | Too many requests |
| 500 | internal_error | Server error |
