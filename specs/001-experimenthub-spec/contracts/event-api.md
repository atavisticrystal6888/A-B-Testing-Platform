# Event Collection API Contract

**Version**: 1.0.0 | **Service**: Event Collector
**Base URL**: `https://{host}/v1`
**Auth**: API Key via `X-API-Key` header

---

## POST /v1/events

Submit a single metric/conversion event (FR-016).

### Request

```json
{
  "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user_abc123",
  "event_type": "conversion",
  "event_name": "checkout_completed",
  "value": 1,
  "properties": {
    "revenue": 49.99,
    "currency": "USD"
  },
  "timestamp": "2026-04-01T12:05:00Z",
  "idempotency_key": "evt_abc123_checkout_1711972800"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| experiment_id | string (UUID) | Yes | Experiment to attribute the event to |
| user_id | string | Yes | External user identifier (max 255 chars) |
| event_type | string | Yes | One of: `conversion`, `metric`, `revenue` |
| event_name | string | Yes | Event name (max 100 chars, e.g., "checkout_completed") |
| value | number | No | Numeric value (required for `metric` and `revenue` types) |
| properties | object | No | Arbitrary key-value metadata |
| timestamp | string (ISO 8601) | Yes | Client-side event timestamp |
| idempotency_key | string | Yes | Unique key for deduplication (max 255 chars) (FR-018) |

### Response — 202 Accepted

```json
{
  "status": "accepted",
  "event_id": "880e8400-e29b-41d4-a716-446655440010",
  "received_at": "2026-04-01T12:05:01Z"
}
```

### Response — 400 Bad Request

```json
{
  "error": "validation_error",
  "message": "Missing required field: user_id",
  "details": [
    { "field": "user_id", "error": "is required" }
  ]
}
```

### Response — 503 Service Unavailable

When the event buffer is full (Kafka unavailable + buffer at capacity):

```json
{
  "error": "service_unavailable",
  "message": "Event ingestion temporarily unavailable. Please retry.",
  "retry_after": 30
}
```

**Headers**: `Retry-After: 30`

---

## POST /v1/events/batch

Submit multiple events in a single request (FR-017).

### Request

```json
{
  "events": [
    {
      "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "user_abc123",
      "event_type": "conversion",
      "event_name": "checkout_completed",
      "value": 1,
      "timestamp": "2026-04-01T12:05:00Z",
      "idempotency_key": "evt_abc123_checkout_001"
    },
    {
      "experiment_id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "user_def456",
      "event_type": "metric",
      "event_name": "page_load_time",
      "value": 1.234,
      "timestamp": "2026-04-01T12:05:01Z",
      "idempotency_key": "evt_def456_plt_001"
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| events | array | Yes | Array of event objects (max 1000 per request, FR-017) |

### Response — 202 Accepted (all valid)

```json
{
  "status": "accepted",
  "accepted": 2,
  "rejected": 0,
  "errors": [],
  "received_at": "2026-04-01T12:05:01Z"
}
```

### Response — 207 Multi-Status (partial success)

When some events are valid and others are malformed (FR-019):

```json
{
  "status": "partial",
  "accepted": 1,
  "rejected": 1,
  "errors": [
    {
      "index": 1,
      "error": "validation_error",
      "message": "Missing required field: user_id",
      "details": [{ "field": "user_id", "error": "is required" }]
    }
  ],
  "received_at": "2026-04-01T12:05:01Z"
}
```

### Response — 400 Bad Request (all invalid)

```json
{
  "error": "validation_error",
  "message": "All events in the batch failed validation",
  "rejected": 2,
  "errors": [
    { "index": 0, "error": "validation_error", "message": "Invalid event_type: 'click'" },
    { "index": 1, "error": "validation_error", "message": "Missing required field: timestamp" }
  ]
}
```

---

## Event Schema Validation Rules

| Field | Validation |
|-------|-----------|
| experiment_id | Valid UUID format |
| user_id | Non-empty, max 255 chars |
| event_type | Must be one of: `conversion`, `metric`, `revenue` |
| event_name | Non-empty, max 100 chars, alphanumeric + underscores |
| value | If event_type is `metric` or `revenue`, value is required and must be numeric |
| timestamp | Valid ISO 8601 datetime, not more than 24 hours in the future |
| idempotency_key | Non-empty, max 255 chars |
| properties | If present, must be a valid JSON object, max 10KB |

---

## Deduplication Behavior (FR-018)

- Events with the same `idempotency_key` within the same tenant are deduplicated.
- The first event with a given key is accepted; subsequent submissions return 202 Accepted silently (idempotent).
- Deduplication window: 7 days (matching Kafka retention for `experimenthub.events.raw`).
- Deduplication is enforced at the database level via `UNIQUE(tenant_id, idempotency_key)` on `experiment_events_raw`.

---

## Performance Requirements

| Endpoint | p99 Latency | Throughput | Notes |
|----------|-------------|------------|-------|
| POST /v1/events | < 10ms | 50,000 events/sec | NFR-002. Async write to Kafka. |
| POST /v1/events/batch | < 50ms | 5,000 batches/sec | At avg 10 events/batch = 50K events/sec. |

## Error Codes

| HTTP Status | Error Code | When |
|-------------|-----------|------|
| 202 | — | Events accepted for processing |
| 207 | — | Partial success (some events valid, some rejected) |
| 400 | validation_error | All events invalid |
| 401 | unauthorized | Invalid/missing API key |
| 413 | payload_too_large | Batch exceeds 1000 events |
| 429 | rate_limited | Per-tenant rate limit exceeded |
| 503 | service_unavailable | Kafka down + buffer full |
