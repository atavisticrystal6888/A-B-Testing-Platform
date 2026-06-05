# Data Model: ExperimentHub

**Branch**: `001-experimenthub-spec` | **Date**: 2026-04-01
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## Entity-Relationship Overview

```
Tenant 1──* User
Tenant 1──* APIKey
Tenant 1──* Experiment
Tenant 1──* MetricDefinition
Tenant 1──* Segment
Tenant 1──* FeatureFlag
Tenant 1──* ExperimentGroup

Experiment *──1 ExperimentGroup (optional)
Experiment 1──* Variant
Experiment 1──* ExperimentMetric ──1 MetricDefinition
Experiment 1──* TargetingRule
Experiment 1──* ExperimentEvent (raw events)
Experiment 1──* ExperimentResultDaily (aggregated)
Experiment 1──* StatisticalAnalysis
Experiment 1──* AuditLog

Variant 1──* Assignment
Variant 1──* ExperimentEvent
Variant 1──* ExperimentResultDaily

User *──1 Role
TargetingRule *──1 Segment (optional, if using named segment)
FeatureFlag 1──* TargetingRule
```

---

## PostgreSQL Tables

### Multi-Tenancy Foundation

All tenant-scoped tables include a `tenant_id UUID NOT NULL` column with a Row-Level Security (RLS) policy:

```sql
-- Applied to every tenant-scoped table:
ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON {table}
  USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
```

Tenant context is set at the beginning of every request:
```sql
SET LOCAL app.current_tenant_id = '{tenant_uuid}';
```

---

### tenants

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| name | VARCHAR(255) | NOT NULL | Organization name |
| slug | VARCHAR(100) | NOT NULL, UNIQUE | URL-safe identifier |
| settings | JSONB | NOT NULL, DEFAULT '{}' | Rate limits, feature toggles, defaults, per-tenant anonymization salt |
| deletion_scheduled_at | TIMESTAMPTZ | | Non-null when tenant offboarding initiated (FR-073). Permanent deletion after 72h grace period. |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(slug)`
**RLS**: None — tenants table is not tenant-scoped (superadmin access only)
**Note**: `settings.anonymization_salt` stores a per-tenant cryptographic salt used by FR-072 GDPR anonymization. This salt MUST NOT be exposed via any API.

---

### users

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| email | VARCHAR(255) | NOT NULL | |
| password_hash | VARCHAR(255) | NOT NULL | Bcrypt hash |
| role | VARCHAR(20) | NOT NULL, CHECK(role IN ('viewer','editor','admin')) | FR-042 |
| last_login_at | TIMESTAMPTZ | | |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, email)`, `(tenant_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### api_keys

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| key_prefix | VARCHAR(8) | NOT NULL | First 8 chars for identification (e.g., "eh_live_") |
| key_hash | VARCHAR(255) | NOT NULL | SHA-256 hash of the full key. Raw key shown once at creation. |
| name | VARCHAR(255) | NOT NULL | Human-readable label |
| expires_at | TIMESTAMPTZ | | NULL = no expiry (FR-041) |
| revoked_at | TIMESTAMPTZ | | NULL = active |
| last_used_at | TIMESTAMPTZ | | |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(key_hash)`, `(tenant_id)`, `(key_prefix)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### experiments

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| experiment_group_id | UUID | FK(experiment_groups), NULL | Mutual exclusion group (FR-036) |
| key | VARCHAR(100) | NOT NULL | URL-safe key for SDK (e.g., "checkout-button-color") |
| name | VARCHAR(255) | NOT NULL | Human-readable name |
| hypothesis | TEXT | NOT NULL | Required before launch (FR-005) |
| description | TEXT | | |
| feature_tag | VARCHAR(100) | | Optional tag for grouping experiments on same feature/page (FR-075, US21). Used for overlap detection and timeline views. e.g., "checkout-page", "pricing-hero" |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'draft', CHECK(status IN ('draft','running','paused','concluded')) | FR-002 |
| conclusion_decision | VARCHAR(20) | CHECK(conclusion_decision IN ('ship_variant','revert_to_control','inconclusive')) | FR-007 |
| conclusion_rationale | TEXT | | FR-007 |
| concluded_by | UUID | FK(users) | |
| scheduled_start_at | TIMESTAMPTZ | | FR: US10 |
| scheduled_end_at | TIMESTAMPTZ | | FR: US10 |
| started_at | TIMESTAMPTZ | | Actual start time |
| concluded_at | TIMESTAMPTZ | | Actual conclusion time |
| version | INTEGER | NOT NULL, DEFAULT 1 | Optimistic locking (FR-006) |
| archived | BOOLEAN | NOT NULL, DEFAULT false | FR-053 |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, key)`, `(tenant_id, status)`, `(tenant_id, experiment_group_id)`, `(tenant_id, archived, status)`, `(tenant_id, feature_tag, status)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### variants

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| experiment_id | UUID | NOT NULL, FK(experiments) ON DELETE CASCADE | |
| key | VARCHAR(100) | NOT NULL | URL-safe key (e.g., "control", "treatment_a") |
| name | VARCHAR(255) | NOT NULL | Human-readable name |
| description | TEXT | | |
| is_control | BOOLEAN | NOT NULL, DEFAULT false | Exactly one per experiment |
| traffic_allocation | INTEGER | NOT NULL, CHECK(traffic_allocation BETWEEN 0 AND 10000) | Basis points (50% = 5000) for precision |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | Display ordering |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, experiment_id, key)`, `(experiment_id)`
**Constraints**: Traffic allocation across all variants for an experiment must sum to 10000 (enforced at application level, FR-004)
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### experiment_groups

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| name | VARCHAR(255) | NOT NULL | |
| description | TEXT | | |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, name)`, `(tenant_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### metric_definitions

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| key | VARCHAR(100) | NOT NULL | e.g., "checkout_conversion" |
| name | VARCHAR(255) | NOT NULL | |
| description | TEXT | | |
| metric_type | VARCHAR(20) | NOT NULL, CHECK(metric_type IN ('count','ratio','sum','funnel')) | FR-060, FR-061 |
| definition | JSONB | NOT NULL | Type-specific config (numerator/denominator events, funnel steps) |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, key)`, `(tenant_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### experiment_metrics

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| experiment_id | UUID | NOT NULL, FK(experiments) ON DELETE CASCADE | |
| metric_definition_id | UUID | NOT NULL, FK(metric_definitions) | |
| role | VARCHAR(20) | NOT NULL, CHECK(role IN ('primary','secondary','guardrail')) | FR-062, FR-063 |
| guardrail_threshold | DECIMAL | | Only for role='guardrail' (FR-063) |
| guardrail_direction | VARCHAR(10) | CHECK(guardrail_direction IN ('above','below')) | e.g., error_rate 'above' 0.05 = breach |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, experiment_id, metric_definition_id)`, `(experiment_id)`
**Constraints**: Exactly one metric with role='primary' per experiment (enforced at application level, FR-005)
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### targeting_rules

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| target_type | VARCHAR(20) | NOT NULL, CHECK(target_type IN ('experiment','feature_flag')) | |
| target_id | UUID | NOT NULL | experiment_id or feature_flag_id |
| segment_id | UUID | FK(segments), NULL | If using a named segment |
| attribute | VARCHAR(100) | | User attribute key (e.g., "country") |
| operator | VARCHAR(20) | CHECK(operator IN ('eq','neq','contains','in','gt','lt')) | FR-031 |
| value | JSONB | NOT NULL | Operator value(s) |
| logic_group | INTEGER | NOT NULL, DEFAULT 0 | Rules in same group = AND; across groups = OR (FR-032) |
| sort_order | INTEGER | NOT NULL, DEFAULT 0 | Evaluation order |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `(tenant_id, target_type, target_id)`, `(tenant_id, segment_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### segments

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| name | VARCHAR(255) | NOT NULL | e.g., "US Mobile Users" |
| description | TEXT | | |
| rules | JSONB | NOT NULL | Serialized targeting rule conditions |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, name)`, `(tenant_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### feature_flags

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| key | VARCHAR(100) | NOT NULL | SDK lookup key |
| name | VARCHAR(255) | NOT NULL | |
| description | TEXT | | |
| enabled | BOOLEAN | NOT NULL, DEFAULT false | Global on/off |
| rollout_percentage | INTEGER | NOT NULL, DEFAULT 0, CHECK(rollout_percentage BETWEEN 0 AND 10000) | Basis points (FR-048) |
| version | INTEGER | NOT NULL, DEFAULT 1 | Optimistic locking |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, key)`, `(tenant_id, enabled)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### assignments

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| experiment_id | UUID | NOT NULL, FK(experiments) | |
| variant_id | UUID | NOT NULL, FK(variants) | |
| user_id | VARCHAR(255) | NOT NULL | External user identifier |
| assigned_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, experiment_id, user_id)`, `(tenant_id, experiment_id, variant_id)`
**Note**: The assignments table serves a dual purpose: (1) storing override assignments for QA/testing (FR-015), and (2) persisting hash-based assignments for returning users to prevent flip-flopping when traffic allocation changes on a running experiment (FR-014, tasks T316/T317). On first hash-based assignment, the result is persisted here; subsequent calls check for an existing assignment before re-hashing.
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### experiment_events_raw (PARTITIONED)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL | |
| experiment_id | UUID | NOT NULL | |
| variant_id | UUID | NOT NULL | |
| user_id | VARCHAR(255) | NOT NULL | External user identifier |
| event_type | VARCHAR(20) | NOT NULL, CHECK(event_type IN ('conversion','metric','revenue')) | FR-016 |
| event_name | VARCHAR(100) | NOT NULL | e.g., "checkout_completed" |
| value | DECIMAL | | Numeric value (optional) |
| properties | JSONB | DEFAULT '{}' | Custom properties |
| idempotency_key | VARCHAR(255) | NOT NULL | FR-018 |
| is_bot | BOOLEAN | NOT NULL, DEFAULT false | FR-021 |
| is_post_conclusion | BOOLEAN | NOT NULL, DEFAULT false | FR-020 |
| timestamp | TIMESTAMPTZ | NOT NULL | Client-provided event time |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Server receipt time |

**Partitioning**: Range by `inserted_at` (monthly partitions)
```sql
CREATE TABLE experiment_events_raw (
  -- columns above
) PARTITION BY RANGE (inserted_at);

CREATE TABLE experiment_events_raw_2026_04
  PARTITION OF experiment_events_raw
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
```

**Indexes** (per partition):
- `UNIQUE(tenant_id, idempotency_key)` — deduplication
- `(tenant_id, experiment_id, inserted_at)` — primary query pattern
- `(tenant_id, experiment_id, variant_id, event_name)` — aggregation queries

**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`
**Retention**: Partitions older than 90 days are dropped (FR-051)

---

### experiment_results_daily (PARTITIONED)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL | |
| experiment_id | UUID | NOT NULL | |
| variant_id | UUID | NOT NULL | |
| metric_definition_id | UUID | NOT NULL | |
| date | DATE | NOT NULL | Aggregation date |
| sample_size | BIGINT | NOT NULL, DEFAULT 0 | Unique users |
| conversions | BIGINT | NOT NULL, DEFAULT 0 | For count metrics |
| sum_value | DECIMAL | NOT NULL, DEFAULT 0 | For sum/revenue metrics |
| sum_squared_value | DECIMAL | NOT NULL, DEFAULT 0 | For variance calculation |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Partitioning**: Range by `date` (monthly)
**Indexes** (per partition):
- `UNIQUE(tenant_id, experiment_id, variant_id, metric_definition_id, date)`
- `(tenant_id, experiment_id, date)`

**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`
**Retention**: Never dropped (FR-052) — aggregated results are permanent.

---

### statistical_analyses

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| experiment_id | UUID | NOT NULL, FK(experiments) | |
| metric_definition_id | UUID | NOT NULL, FK(metric_definitions) | |
| analysis_type | VARCHAR(20) | NOT NULL, CHECK(analysis_type IN ('frequentist','bayesian','sequential')) | |
| methodology | VARCHAR(50) | NOT NULL | e.g., "z_test_proportions", "beta_binomial", "obrien_fleming" |
| parameters | JSONB | NOT NULL | Input parameters (alpha, prior, spending function) |
| results | JSONB | NOT NULL | Full results (p-value, CI, effect size, posterior, etc.) |
| sample_sizes | JSONB | NOT NULL | Per-variant sample sizes at time of analysis |
| is_significant | BOOLEAN | | NULL if insufficient data |
| winning_variant_id | UUID | FK(variants) | NULL if no winner |
| computed_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `(tenant_id, experiment_id, metric_definition_id, computed_at DESC)`, `(tenant_id, experiment_id, analysis_type)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`

---

### audit_logs (PARTITIONED)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL | |
| actor_id | UUID | | User who performed the action (NULL for system actions) |
| actor_type | VARCHAR(20) | NOT NULL, CHECK(actor_type IN ('user','system','api_key')) | |
| action | VARCHAR(50) | NOT NULL | e.g., "experiment.created", "experiment.started", "variant.updated" |
| resource_type | VARCHAR(50) | NOT NULL | e.g., "experiment", "feature_flag", "api_key" |
| resource_id | UUID | NOT NULL | |
| changes | JSONB | NOT NULL, DEFAULT '{}' | Before/after state (FR-070) |
| reason | TEXT | | Optional reason (FR-070) |
| metadata | JSONB | DEFAULT '{}' | Request ID, IP, user agent |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Partitioning**: Range by `inserted_at` (monthly)
**Indexes** (per partition):
- `(tenant_id, resource_type, resource_id, inserted_at DESC)`
- `(tenant_id, actor_id, inserted_at DESC)`
- `(tenant_id, action, inserted_at DESC)`

**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`
**Immutability**: No UPDATE or DELETE permissions granted. Application enforces append-only (FR-071).

```sql
-- Revoke UPDATE/DELETE on audit_logs from application role
REVOKE UPDATE, DELETE ON audit_logs FROM experimenthub_app;
```

---

### assignment_overrides

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| experiment_id | UUID | NOT NULL, FK(experiments) | |
| variant_id | UUID | NOT NULL, FK(variants) | |
| user_id | VARCHAR(255) | NOT NULL | External user identifier to force-assign |
| created_by | UUID | NOT NULL, FK(users) | Who created the override |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `UNIQUE(tenant_id, experiment_id, user_id)`, `(tenant_id, experiment_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`
**Purpose**: FR-015 — QA/testing overrides that take precedence over hash-based assignment.

---

### anonymization_requests

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, DEFAULT gen_random_uuid() | |
| tenant_id | UUID | NOT NULL, FK(tenants) | |
| requested_by | UUID | NOT NULL, FK(users) | Actor who initiated the request |
| target_user_id | VARCHAR(255) | NOT NULL | Original participant user_id to anonymize |
| pseudonymized_user_id | VARCHAR(64) | | SHA-256(tenant_id \|\| user_id \|\| salt) result |
| status | VARCHAR(20) | NOT NULL, DEFAULT 'pending', CHECK(status IN ('pending','processing','completed','failed')) | |
| records_anonymized | JSONB | DEFAULT '{}' | Count per table: {"assignments": 42, "experiment_events_raw": 1500, "audit_logs": 12} |
| error_message | TEXT | | Populated on failure |
| started_at | TIMESTAMPTZ | | Processing start time |
| completed_at | TIMESTAMPTZ | | Processing completion time |
| inserted_at | TIMESTAMPTZ | NOT NULL, DEFAULT now() | |

**Indexes**: `(tenant_id, status)`, `(tenant_id, target_user_id)`
**RLS**: `tenant_id = current_setting('app.current_tenant_id')::uuid`
**Purpose**: FR-072 — Track GDPR anonymization request progress. For participants with >100K records, processing is executed as a background job; this table enables `GET /api/v1/gdpr/anonymization-requests/:id` status polling.

---

## Kafka Topic Schemas

### experimenthub.events.inbound

Pre-validation inbound event queue. Events are produced by the REST API (EventController) and consumed by the Broadway pipeline for validation, deduplication, and persistence. Invalid events are rejected at this stage; valid events are forwarded to `experimenthub.events.raw`.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["tenant_id", "experiment_id", "user_id", "event_type", "event_name", "idempotency_key", "timestamp"],
  "properties": {
    "schema_version": { "type": "integer", "const": 1 },
    "tenant_id": { "type": "string", "format": "uuid" },
    "experiment_id": { "type": "string", "format": "uuid" },
    "variant_id": { "type": ["string", "null"], "format": "uuid" },
    "user_id": { "type": "string", "maxLength": 255 },
    "event_type": { "type": "string", "enum": ["conversion", "metric", "revenue"] },
    "event_name": { "type": "string", "maxLength": 100 },
    "value": { "type": ["number", "null"] },
    "properties": { "type": "object" },
    "user_agent": { "type": ["string", "null"], "maxLength": 500 },
    "idempotency_key": { "type": "string", "maxLength": 255 },
    "timestamp": { "type": "string", "format": "date-time" },
    "received_at": { "type": "string", "format": "date-time" }
  }
}
```

**Topic config**: `retention.ms=172800000` (48h), `partitions=12`, `replication.factor=3`
**Key**: `tenant_id:experiment_id` (partition by experiment for ordering)

### experimenthub.events.raw

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["tenant_id", "experiment_id", "user_id", "event_type", "event_name", "idempotency_key", "timestamp"],
  "properties": {
    "schema_version": { "type": "integer", "const": 1 },
    "tenant_id": { "type": "string", "format": "uuid" },
    "experiment_id": { "type": "string", "format": "uuid" },
    "variant_id": { "type": "string", "format": "uuid" },
    "user_id": { "type": "string", "maxLength": 255 },
    "event_type": { "type": "string", "enum": ["conversion", "metric", "revenue"] },
    "event_name": { "type": "string", "maxLength": 100 },
    "value": { "type": ["number", "null"] },
    "properties": { "type": "object" },
    "idempotency_key": { "type": "string", "maxLength": 255 },
    "timestamp": { "type": "string", "format": "date-time" }
  }
}
```

### experimenthub.assignments

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["tenant_id", "experiment_id", "variant_id", "user_id", "assigned_at"],
  "properties": {
    "schema_version": { "type": "integer", "const": 1 },
    "tenant_id": { "type": "string", "format": "uuid" },
    "experiment_id": { "type": "string", "format": "uuid" },
    "variant_id": { "type": "string", "format": "uuid" },
    "user_id": { "type": "string", "maxLength": 255 },
    "assignment_source": { "type": "string", "enum": ["hash", "override", "fallback"] },
    "assigned_at": { "type": "string", "format": "date-time" }
  }
}
```

### experimenthub.lifecycle

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["tenant_id", "experiment_id", "event_type", "actor_id", "occurred_at"],
  "properties": {
    "schema_version": { "type": "integer", "const": 1 },
    "tenant_id": { "type": "string", "format": "uuid" },
    "experiment_id": { "type": "string", "format": "uuid" },
    "event_type": { "type": "string", "enum": ["created", "started", "paused", "resumed", "concluded"] },
    "actor_id": { "type": "string", "format": "uuid" },
    "actor_type": { "type": "string", "enum": ["user", "system"] },
    "previous_status": { "type": ["string", "null"] },
    "new_status": { "type": "string" },
    "metadata": { "type": "object" },
    "occurred_at": { "type": "string", "format": "date-time" }
  }
}
```

---

## Redis Key Patterns

| Pattern | Type | TTL | Purpose |
|---------|------|-----|---------|
| `exp:{tenant_id}:{experiment_key}` | Hash | 5 min (invalidate on config change) | Cached experiment config (variants, allocation, status, targeting) |
| `flag:{tenant_id}:{flag_key}` | Hash | 5 min | Cached feature flag config |
| `override:{tenant_id}:{experiment_id}:{user_id}` | String | None (until deleted) | Assignment override variant_id |
| `rate:{tenant_id}:{api_key_prefix}:{window}` | String (counter) | 60 sec | Rate limiting counter per API key per minute |
| `rate:{tenant_id}:{api_key_prefix}:daily` | String (counter) | 24 hours | Daily rate limit counter |
| `lock:exp:{experiment_id}` | String | 30 sec | Distributed lock for experiment state transitions |

### Cache Invalidation Strategy
- On experiment config change (variants, allocation, targeting): delete `exp:{tenant_id}:{experiment_key}` from Redis.
- On feature flag change: delete `flag:{tenant_id}:{flag_key}`.
- Cache is populated lazily on next request (cache-aside pattern).
- No cache warming — the 5-minute TTL ensures stale data resolves quickly even if invalidation fails.
