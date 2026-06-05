# Assignment API Contract

**Version**: 1.0.0 | **Service**: Assignment Engine
**Base URL**: `https://{host}/v1`
**Auth**: API Key via `X-API-Key` header

---

## POST /v1/assign

Get variant assignment for a single user + experiment.

### Request

```json
{
  "user_id": "user_abc123",
  "experiment_key": "checkout-button-color",
  "attributes": {
    "country": "US",
    "device": "mobile",
    "plan": "pro"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | string | Yes | External user identifier (max 255 chars) |
| experiment_key | string | Yes | Experiment key (URL-safe, max 100 chars) |
| attributes | object | No | User attributes for targeting rule evaluation (FR-031) |

### Response — 200 OK

```json
{
  "experiment_key": "checkout-button-color",
  "variant_key": "treatment",
  "variant_name": "Green Button",
  "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
  "variant_id": "660e8400-e29b-41d4-a716-446655440001",
  "is_control": false,
  "enrolled": true,
  "assigned_at": "2026-04-01T12:00:00Z"
}
```

### Response — 200 OK (not enrolled)

When user doesn't match targeting rules or experiment not running:

```json
{
  "experiment_key": "checkout-button-color",
  "variant_key": "control",
  "variant_name": "Blue Button",
  "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
  "variant_id": "660e8400-e29b-41d4-a716-446655440003",
  "is_control": true,
  "enrolled": false,
  "reason": "targeting_mismatch"
}
```

### Response — 404 Not Found

```json
{
  "error": "experiment_not_found",
  "message": "Experiment 'checkout-button-color' does not exist"
}
```

### Response — 401 Unauthorized

```json
{
  "error": "unauthorized",
  "message": "Invalid or missing API key"
}
```

### Response — 429 Too Many Requests

```json
{
  "error": "rate_limited",
  "message": "Rate limit exceeded",
  "retry_after": 30
}
```

**Headers**: `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`

---

## POST /v1/assign/batch

Batch assignment for a single user across multiple experiments (FR-013).

### Request

```json
{
  "user_id": "user_abc123",
  "experiment_keys": [
    "checkout-button-color",
    "pricing-page-layout",
    "onboarding-flow-v2"
  ],
  "attributes": {
    "country": "US",
    "device": "mobile"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | string | Yes | External user identifier |
| experiment_keys | string[] | Yes | Array of experiment keys (max 50) |
| attributes | object | No | User attributes for targeting |

### Response — 200 OK

```json
{
  "user_id": "user_abc123",
  "assignments": [
    {
      "experiment_key": "checkout-button-color",
      "variant_key": "treatment",
      "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
      "variant_id": "660e8400-e29b-41d4-a716-446655440001",
      "is_control": false,
      "enrolled": true
    },
    {
      "experiment_key": "pricing-page-layout",
      "variant_key": "control",
      "experiment_id": "550e8400-e29b-41d4-a716-446655440002",
      "variant_id": "660e8400-e29b-41d4-a716-446655440005",
      "is_control": true,
      "enrolled": false,
      "reason": "experiment_not_running"
    },
    {
      "experiment_key": "onboarding-flow-v2",
      "variant_key": "variant_b",
      "experiment_id": "550e8400-e29b-41d4-a716-446655440003",
      "variant_id": "660e8400-e29b-41d4-a716-446655440006",
      "is_control": false,
      "enrolled": true
    }
  ],
  "assigned_at": "2026-04-01T12:00:00Z"
}
```

---

## GET /v1/flags/{flag_key}

Evaluate a feature flag for a user (FR-046).

### Request

Query parameters:

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| user_id | string | Yes | External user identifier |
| attributes | string | No | URL-encoded JSON of user attributes |

Example: `GET /v1/flags/new-checkout-flow?user_id=user_abc123&attributes=%7B%22plan%22%3A%22pro%22%7D`

### Response — 200 OK

```json
{
  "flag_key": "new-checkout-flow",
  "enabled": true,
  "variant_key": "on",
  "flag_id": "770e8400-e29b-41d4-a716-446655440005",
  "rollout_percentage": 2500,
  "evaluated_at": "2026-04-01T12:00:00Z"
}
```

### Response — 200 OK (flag disabled)

```json
{
  "flag_key": "new-checkout-flow",
  "enabled": false,
  "variant_key": "off",
  "flag_id": "770e8400-e29b-41d4-a716-446655440005",
  "rollout_percentage": 0,
  "evaluated_at": "2026-04-01T12:00:00Z"
}
```

### Response — 404 Not Found

```json
{
  "error": "flag_not_found",
  "message": "Feature flag 'new-checkout-flow' does not exist"
}
```

---

## Performance Requirements

| Endpoint | p99 Latency | Throughput | Notes |
|----------|-------------|------------|-------|
| POST /v1/assign | < 5ms | 10,000 rps | NFR-001. Rust NIF + Redis cache. |
| POST /v1/assign/batch | < 10ms | 2,000 rps | Linear in experiment count. |
| GET /v1/flags/{key} | < 5ms | 10,000 rps | Same path as assignment. |

## Error Codes

| HTTP Status | Error Code | When |
|-------------|-----------|------|
| 200 | — | Success (including "not enrolled" — still returns control variant) |
| 400 | invalid_request | Missing required fields, invalid format |
| 401 | unauthorized | Invalid/missing API key |
| 404 | experiment_not_found / flag_not_found | Unknown key |
| 429 | rate_limited | Per-tenant rate limit exceeded |
| 500 | internal_error | Server error (fail-open: SDK should use cached/control) |
