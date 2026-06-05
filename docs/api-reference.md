# ExperimentHub Public API Reference

Base URL: `https://your-instance.example.com/api/v1`

All endpoints require `Authorization: Bearer <api_key>` and `X-Tenant-ID: <tenant_id>` headers.

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

### GET /experiments
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

### POST /experiments
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

### GET /experiments/:id
Get experiment details.

### PUT /experiments/:id
Update experiment configuration (draft only).

### POST /experiments/:id/launch
Start running the experiment.

### POST /experiments/:id/pause
Pause a running experiment.

### POST /experiments/:id/resume
Resume a paused experiment.

### POST /experiments/:id/conclude
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

### POST /assignments
Get a variant assignment for a user.

**Request Body:**
```json
{
  "experiment_id": "uuid-or-key",
  "user_id": "user-123",
  "context": {
    "platform": "web",
    "country": "US"
  }
}
```

**Response:** `200 OK`
```json
{
  "data": {
    "variant_id": "blue",
    "experiment_id": "uuid",
    "is_new": true
  }
}
```

---

## Events

### POST /events
Track a single event.

**Request Body:**
```json
{
  "event_type": "conversion",
  "experiment_id": "uuid",
  "variant_id": "blue",
  "user_id": "user-123",
  "timestamp": "2024-01-15T10:30:00Z",
  "properties": {
    "value": 49.99
  }
}
```

**Response:** `202 Accepted`

### POST /events/batch
Track multiple events.

**Request Body:**
```json
{
  "events": [
    { "event_type": "page_view", "experiment_id": "uuid", ... },
    { "event_type": "click", "experiment_id": "uuid", ... }
  ]
}
```

**Response:** `202 Accepted`

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

### GET /flags/:flag_key
Evaluate a feature flag.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| user_id | string | User ID for targeting |
| context | object | Additional context for targeting rules |

**Response:** `200 OK`
```json
{
  "data": {
    "flag_key": "dark-mode",
    "enabled": true,
    "variant": "enabled",
    "rollout_percentage": 50
  }
}
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
