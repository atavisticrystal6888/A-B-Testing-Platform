# Tasks: ExperimentHub — A/B Testing & Experimentation Platform

**Input**: Design documents from `/specs/001-experimenthub-spec/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: TDD is mandatory per Constitution Article III (v1.0.1). All user story phases include test tasks that MUST pass (fail first ? implement ? green).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Exact file paths included in each task description

## Path Conventions

Multi-service monorepo structure from plan.md:

- **Elixir Umbrella**: `apps/experiment_hub/`, `apps/experiment_hub_web/`, `apps/event_collector/`, `apps/assignment_engine/`
- **Rust Library**: `assignment_core/`
- **Python Statistical Engine**: `statistical_engine/`
- **Python Data Pipeline (Background Workers)**: `data_pipeline/` _(not a core service per Constitution v1.0.1 Article I)_
- **React Dashboard**: `dashboard/`
- **Infrastructure**: `docker-compose.yml`, `docker-compose.test.yml`, `k6/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the monorepo skeleton, initialize all projects, and configure tooling/infrastructure

- [X] T001 Create Elixir umbrella project with `mix new experiment_hub_umbrella --umbrella` at repository root
- [X] T002 Create `apps/experiment_hub` app with `mix new experiment_hub --sup` for core domain (Ecto schemas, contexts, business logic)
- [X] T003 Create `apps/experiment_hub_web` app with `mix phx.new experiment_hub_web --no-ecto --no-html --no-mailer` for Phoenix web layer (REST API, channels, plugs)
- [X] T004 Create `apps/event_collector` app with `mix new event_collector --sup` for Broadway-based event ingestion
- [X] T005 Create `apps/assignment_engine` app with `mix new assignment_engine` for Rustler NIF wrapper
- [X] T006 [P] Create Rust workspace with `cargo init --lib` in assignment_core/ with Cargo.toml (murmur3, rustler, wasm-bindgen, serde dependencies)
- [X] T007 [P] Create Python statistical_engine package with pyproject.toml in statistical_engine/ (FastAPI, scipy, numpy, pandas, pymc dependencies)
- [X] T008 [P] Create Python data_pipeline background workers package with pyproject.toml in data_pipeline/ (confluent-kafka-python, psycopg2 dependencies) � background workers, not a 6th core service (Constitution v1.0.1 Article I)
- [X] T009 [P] Create React dashboard app with Vite + TypeScript in dashboard/ (React 18, React Router 6, TanStack Query 5, Recharts, shadcn/ui, Zod)
- [X] T010 [P] Create docker-compose.yml with PostgreSQL 16, Apache Kafka 3.7 (KRaft mode, no Zookeeper), and Redis 7 at repository root
- [X] T011 [P] Create docker-compose.test.yml with ephemeral test containers at repository root
- [X] T012 Configure Elixir umbrella mix.exs dependencies: Phoenix 1.7+, Ecto 3.11+, Broadway, BroadwayKafka, Jason, Oban, NimbleOptions, Rustler, Mox, StreamData, Elixlsx in mix.exs
- [X] T013 [P] Configure Elixir code quality tools: .formatter.exs, .credo.exs in repository root
- [X] T014 [P] Configure TypeScript/React tooling: tsconfig.json, ESLint, Prettier in dashboard/
- [X] T015 [P] Configure Python linting: ruff.toml and mypy.ini in statistical_engine/ and data_pipeline/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Database & Multi-Tenancy Foundation

- [X] T016 Configure Ecto Repo with PostgreSQL 16 connection pool in apps/experiment_hub/lib/experiment_hub/repo.ex
- [X] T017 Create tenants Ecto schema and migration in apps/experiment_hub/lib/experiment_hub/tenants/tenant.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T018 Create users Ecto schema and migration with pbkdf2 password hashing in apps/experiment_hub/lib/experiment_hub/tenants/user.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T019 Create api_keys Ecto schema and migration with SHA-256 key hashing in apps/experiment_hub/lib/experiment_hub/tenants/api_key.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T020 Create RLS setup migration enabling row-level security and tenant_isolation policies on all tenant-scoped tables in apps/experiment_hub/priv/repo/migrations/
- [X] T021 Implement Tenants context with CRUD for tenants, users, and api_keys in apps/experiment_hub/lib/experiment_hub/tenants.ex
- [X] T022 Implement tenant context Plug that sets `SET LOCAL app.current_tenant_id` on each request in apps/experiment_hub_web/lib/experiment_hub_web/plugs/tenant_context.ex
- [X] T023 Implement cryptographically secure API key generation with `eh_live_` prefix and SHA-256 hashing in apps/experiment_hub/lib/experiment_hub/tenants/api_key_generator.ex

### Authentication, Authorization & Middleware

- [X] T024 Implement API key authentication Plug that validates `X-API-Key` header against api_keys table in apps/experiment_hub_web/lib/experiment_hub_web/plugs/api_key_auth.ex
- [X] T025 Implement JWT session authentication Plug for dashboard login in apps/experiment_hub_web/lib/experiment_hub_web/plugs/session_auth.ex
- [X] T026 Implement RBAC authorization Plug enforcing viewer/editor/admin role checks in apps/experiment_hub_web/lib/experiment_hub_web/plugs/authorize.ex
- [X] T027 Implement rate limiting Plug using Redis counters per API key per minute in apps/experiment_hub_web/lib/experiment_hub_web/plugs/rate_limiter.ex
- [X] T028 Implement standard rate limit response headers (X-RateLimit-Remaining, X-RateLimit-Reset, Retry-After) in rate limiter Plug

### Infrastructure & Observability

- [X] T029 [P] Configure Redis connection via Redix in apps/experiment_hub/lib/experiment_hub/redis.ex
- [X] T030 [P] Configure Kafka client connection (brod) for producer use in apps/event_collector/lib/event_collector/kafka/client.ex
- [X] T031 Implement JSON error views with standardized error response format in apps/experiment_hub_web/lib/experiment_hub_web/views/error_view.ex
- [X] T032 Configure structured JSON logging with Logger JSON backend in config/config.exs
- [X] T033 [P] Set up Telemetry metrics (Ecto + Phoenix + VM) in apps/experiment_hub_web/lib/experiment_hub_web/telemetry.ex
- [X] T034 [P] Implement health check endpoint returning service status and dependency connectivity at GET /health in apps/experiment_hub_web/lib/experiment_hub_web/controllers/health_controller.ex
- [X] T322 [P] Implement W3C Trace Context propagation: extract/inject traceparent header on all inbound/outbound HTTP requests, attach trace_id to structured logs and Telemetry events (Constitution Article IX.4) in apps/experiment_hub_web/lib/experiment_hub_web/plugs/trace_context.ex
- [X] T035 Configure Oban job processing with PostgreSQL-backed queue in apps/experiment_hub/lib/experiment_hub/oban_config.ex

### Phoenix Router & API Pipeline

- [X] T036 Create base Phoenix router with API pipeline (JSON parsing, auth plugs, tenant context) in apps/experiment_hub_web/lib/experiment_hub_web/router.ex
- [X] T037 Configure CORS middleware for dashboard cross-origin requests in apps/experiment_hub_web/lib/experiment_hub_web/plugs/cors.ex

### Foundational Tests

- [X] T038 [P] Write ExUnit tests for Tenants context CRUD (tenants, users, api_keys) in apps/experiment_hub/test/experiment_hub/tenants_test.exs
- [X] T039 [P] Write ExUnit tests for API key authentication Plug in apps/experiment_hub_web/test/experiment_hub_web/plugs/api_key_auth_test.exs
- [X] T040 [P] Write ExUnit tests for RBAC authorization Plug with all three roles in apps/experiment_hub_web/test/experiment_hub_web/plugs/authorize_test.exs
- [X] T041 [P] Write ExUnit tests for rate limiting Plug in apps/experiment_hub_web/test/experiment_hub_web/plugs/rate_limiter_test.exs
- [X] T042 [P] Write ExUnit tests for tenant context Plug and RLS isolation in apps/experiment_hub_web/test/experiment_hub_web/plugs/tenant_context_test.exs
- [X] T043 Write integration test verifying RLS: authenticated tenant A never sees tenant B data across experiments, events, and users in apps/experiment_hub/test/experiment_hub/rls_integration_test.exs
- [X] T044 [P] Create ExUnit test helpers and shared fixtures (tenant, user, api_key factories) in apps/experiment_hub/test/support/fixtures.ex

**Checkpoint**: Foundation ready — all auth, multi-tenancy, infrastructure in place. User story implementation can now begin.

---

## Phase 3: User Story 1 — PM Creates an A/B Experiment (Priority: P1) 🎯 MVP

**Goal**: A Product Manager creates a new A/B experiment with hypothesis, variants, traffic allocation, and primary metric through the Management API. Experiments have a state machine (draft → running → paused → concluded).

**Independent Test**: Create an experiment via POST /api/v1/experiments, verify all fields persist, confirm it appears in GET /api/v1/experiments in "draft" state.

### Tests for User Story 1 ⚠️

> **Write these tests FIRST — ensure they FAIL before implementation (Article III)**

- [X] T045 [P] [US1] Write contract test for POST /api/v1/experiments (create experiment with variants and metrics) in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_controller_test.exs
- [X] T046 [P] [US1] Write contract test for GET /api/v1/experiments (list with filters: status, search, sort, pagination) in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_controller_test.exs
- [X] T047 [P] [US1] Write contract test for GET /api/v1/experiments/:id (show experiment detail) in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_controller_test.exs
- [X] T048 [P] [US1] Write contract test for PUT /api/v1/experiments/:id (update with optimistic locking, expect 409 on stale version) in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_controller_test.exs
- [X] T049 [P] [US1] Write unit test for experiment state machine transitions (valid: draft→running, running→paused, etc.; invalid: concluded→running) in apps/experiment_hub/test/experiment_hub/experiments/state_machine_test.exs
- [X] T050 [P] [US1] Write unit test for variant traffic allocation validation (must sum to 10000 basis points) in apps/experiment_hub/test/experiment_hub/experiments/validation_test.exs
- [X] T051 [P] [US1] Write unit test for experiment launch pre-conditions (hypothesis required, primary metric required before draft→running) in apps/experiment_hub/test/experiment_hub/experiments/validation_test.exs
- [X] T052 [P] [US1] Write contract test for POST/GET/PUT/DELETE /api/v1/metric-definitions CRUD in apps/experiment_hub_web/test/experiment_hub_web/controllers/metric_definition_controller_test.exs
- [X] T053 [P] [US1] Write contract test for POST/DELETE /api/v1/experiments/:id/metrics (attach/detach metrics) in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_metric_controller_test.exs
- [X] T054 [P] [US1] Write integration test for full experiment creation workflow: create metric → create experiment → attach metric → launch in apps/experiment_hub/test/experiment_hub/experiments/workflow_integration_test.exs

### Implementation for User Story 1

- [X] T055 [P] [US1] Create experiments Ecto schema and migration with all columns from data-model.md (key, name, hypothesis, feature_tag, status, version, scheduling fields, conclusion fields) in apps/experiment_hub/lib/experiment_hub/experiments/experiment.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T056 [P] [US1] Create variants Ecto schema and migration (key, name, is_control, traffic_allocation in basis points, sort_order) in apps/experiment_hub/lib/experiment_hub/experiments/variant.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T057 [P] [US1] Create metric_definitions Ecto schema and migration (key, name, metric_type, definition JSONB) in apps/experiment_hub/lib/experiment_hub/metrics/metric_definition.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T058 [P] [US1] Create experiment_metrics Ecto schema and migration (role: primary/secondary/guardrail, guardrail_threshold, guardrail_direction) in apps/experiment_hub/lib/experiment_hub/metrics/experiment_metric.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T059 [US1] Implement Experiments context with CRUD: create_experiment/1, get_experiment/1, list_experiments/1, update_experiment/2 in apps/experiment_hub/lib/experiment_hub/experiments.ex
- [X] T060 [US1] Implement experiment state machine module with transition validation (draft→running, running→paused, paused→running, running→concluded, paused→concluded) in apps/experiment_hub/lib/experiment_hub/experiments/state_machine.ex
- [X] T061 [US1] Implement variant validation: traffic allocation must sum to 10000, at least 2 variants, exactly one is_control in apps/experiment_hub/lib/experiment_hub/experiments/variant_validator.ex
- [X] T062 [US1] Implement experiment launch pre-conditions: require hypothesis and primary metric before draft→running transition in apps/experiment_hub/lib/experiment_hub/experiments/launch_validator.ex
- [X] T063 [US1] Implement optimistic locking on experiment updates (version column check, raise on stale) in apps/experiment_hub/lib/experiment_hub/experiments.ex
- [X] T064 [US1] Implement MetricDefinitions context with CRUD in apps/experiment_hub/lib/experiment_hub/metrics.ex
- [X] T065 [US1] Implement ExperimentMetrics management (attach/detach metric to experiment, enforce one primary per experiment) in apps/experiment_hub/lib/experiment_hub/metrics.ex
- [X] T066 [US1] Implement ExperimentController (create, index, show, update) with JSON responses per management-api.md contract. Create response MUST include `warnings` array for overlap detection (FR-075) and `feature_tag` field in apps/experiment_hub_web/lib/experiment_hub_web/controllers/experiment_controller.ex
- [X] T067 [US1] Implement ExperimentView with JSON serialization for experiment list and detail responses in apps/experiment_hub_web/lib/experiment_hub_web/views/experiment_view.ex
- [X] T068 [US1] Implement experiment state transition endpoints (POST start, pause, resume) in apps/experiment_hub_web/lib/experiment_hub_web/controllers/experiment_controller.ex
- [X] T069 [US1] Implement MetricDefinitionController (CRUD endpoints) in apps/experiment_hub_web/lib/experiment_hub_web/controllers/metric_definition_controller.ex
- [X] T070 [US1] Implement ExperimentMetricController (attach/detach endpoints) in apps/experiment_hub_web/lib/experiment_hub_web/controllers/experiment_metric_controller.ex
- [X] T071 [US1] Add experiment and metric routes to Phoenix router in apps/experiment_hub_web/lib/experiment_hub_web/router.ex
- [X] T330 [US1] Implement experiment overlap detection: at experiment creation/update, query running experiments sharing the same `feature_tag` and return a `warnings` array in the response with overlapping experiment names suggesting mutual exclusion group placement (FR-075). Requires `feature_tag` column from T055 in apps/experiment_hub/lib/experiment_hub/experiments/overlap_detector.ex
- [X] T331 [P] [US1] Write unit test for overlap detection: creating experiment on a feature tag with an existing running experiment returns warning with overlapping experiment details in apps/experiment_hub/test/experiment_hub/experiments/overlap_detector_test.exs

**Checkpoint**: Experiments can be created, listed, updated, and transitioned through the state machine via REST API. Overlap warnings protect against unintended experiment interactions. User Story 1 is independently testable.

---

## Phase 4: User Story 2 — Engineer Gets Variant Assignments (Priority: P1)

**Goal**: Deterministic variant assignment using MurmurHash3 via Rust NIF. Same (user_id, experiment_key) always returns the same variant. Sub-5ms p99 latency.

**Independent Test**: Call POST /v1/assign with the same user_id + experiment_key 100 times; verify identical variant returned every time. Run chi-squared test on 100K assignments for uniformity.

### Tests for User Story 2 ⚠️

> **Write these tests FIRST — ensure they FAIL before implementation (Article III)**

- [X] T072 [P] [US2] Write property-based uniformity test with proptest: chi-squared test on 100K+ MurmurHash3 assignments (p > 0.05) in assignment_core/tests/uniformity.rs
- [X] T073 [P] [US2] Write property-based determinism test with proptest: same (user_id, experiment_id) pair always produces same variant in assignment_core/tests/determinism.rs
- [X] T074 [P] [US2] Write cross-platform consistency test: native Rust, NIF, and WASM targets all produce identical assignment results for 10K inputs in assignment_core/tests/cross_platform.rs
- [X] T075 [P] [US2] Write ExUnit test for AssignmentEngine.Native NIF: verify deterministic assignment, uniformity, and control variant fallback in apps/assignment_engine/test/assignment_engine/native_test.exs
- [X] T076 [P] [US2] Write contract test for POST /v1/assign (single assignment with targeting attributes) per assignment-api.md in apps/experiment_hub_web/test/experiment_hub_web/controllers/assign_controller_test.exs
- [X] T077 [P] [US2] Write contract test for POST /v1/assign/batch (batch assignment for user across multiple experiments) in apps/experiment_hub_web/test/experiment_hub_web/controllers/assign_controller_test.exs
- [X] T078 [P] [US2] Write unit test for assignment override precedence (override > hash-based > fallback to control) in apps/experiment_hub/test/experiment_hub/assignments/assignment_test.exs
- [X] T079 [P] [US2] Write integration test for end-to-end assignment: create experiment → launch → assign → verify determinism in apps/experiment_hub/test/experiment_hub/assignments/integration_test.exs

### Implementation for User Story 2

- [X] T080 [P] [US2] Implement MurmurHash3 (128-bit) hashing in assignment_core/src/hash.rs
- [X] T081 [US2] Implement variant selection logic: hash → bucket (mod 10000) → variant lookup based on traffic allocation in assignment_core/src/assignment.rs
- [X] T082 [US2] Implement public API (assign function) in assignment_core/src/lib.rs
- [X] T083 [US2] Implement Rustler NIF bindings (assign_variant function) in assignment_core/src/nif.rs
- [X] T084 [US2] Configure Rustler in apps/assignment_engine/ with native/ directory and NIF loading in apps/assignment_engine/lib/assignment_engine/native.ex
- [X] T085 [P] [US2] Create assignments Ecto schema and migration (for override assignments and audit) in apps/experiment_hub/lib/experiment_hub/assignments/assignment.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T086 [P] [US2] Create assignment_overrides Ecto schema and migration (QA force-assign) in apps/experiment_hub/lib/experiment_hub/assignments/assignment_override.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T087 [US2] Implement Assignments context: assign/2, batch_assign/2, get_override/3, create_override/1 in apps/experiment_hub/lib/experiment_hub/assignments.ex
- [X] T088 [US2] Implement Redis caching for experiment config (exp:{tenant_id}:{experiment_key}) with 5-min TTL and invalidation on config change in apps/experiment_hub/lib/experiment_hub/assignments/experiment_cache.ex
- [X] T089 [US2] Implement AssignController with POST /v1/assign endpoint per assignment-api.md. Response MUST include `enrolled` boolean, `experiment_id`, and `variant_id` fields in all responses (FR-044) in apps/experiment_hub_web/lib/experiment_hub_web/controllers/assign_controller.ex
- [X] T090 [US2] Implement batch assignment endpoint POST /v1/assign/batch (max 50 experiment keys per request). Each assignment in batch response MUST include `experiment_id` and `variant_id` for SDK event submission in apps/experiment_hub_web/lib/experiment_hub_web/controllers/assign_controller.ex
- [X] T091 [US2] Implement fallback behavior: return control variant when experiment not running or assignment errors in apps/experiment_hub/lib/experiment_hub/assignments.ex
- [X] T092 [US2] Implement assignment event publishing to Kafka topic `experimenthub.assignments` in apps/experiment_hub/lib/experiment_hub/assignments/event_publisher.ex
- [X] T093 [US2] Add assignment routes to Phoenix router in apps/experiment_hub_web/lib/experiment_hub_web/router.ex
- [X] T316 [US2] Implement assignment persistence: on first hash-based assignment, persist to assignments table (user_id, experiment_id, variant_id) and check for existing assignment on subsequent calls before re-hashing (FR-014) in apps/experiment_hub/lib/experiment_hub/assignments/assignment_persistence.ex
- [X] T317 [US2] Implement traffic reallocation safety: when traffic allocation changes on a running experiment, returning users keep their persisted variant assignment; only new users follow the updated allocation (FR-014) in apps/experiment_hub/lib/experiment_hub/assignments.ex
- [X] T318 [P] [US2] Write property-based test with StreamData: changing traffic allocation does not flip existing user assignments (100K users, 3 allocation changes, assert zero flip-flops) in apps/experiment_hub/test/experiment_hub/assignments/flip_flop_prevention_test.exs

**Checkpoint**: Engineers can get deterministic variant assignments via REST API. Assignments are cached in Redis, persisted for returning users to prevent flip-flopping (FR-014), and produce Kafka events. User Story 2 is independently testable.

---

## Phase 5: User Story 3 — Event Collector Receives and Persists Metric Events (Priority: P1)

**Goal**: High-throughput event ingestion via Broadway + Kafka. Events are validated, deduplicated, and persisted. Supports single and batch submissions at 50K events/sec.

**Independent Test**: Send events to POST /v1/events and POST /v1/events/batch, verify they appear in experiment_events_raw with correct attributes. Send duplicate idempotency_key and verify deduplication.

### Tests for User Story 3 ⚠️

> **Write these tests FIRST — ensure they FAIL before implementation (Article III)**

- [X] T094 [P] [US3] Write contract test for POST /v1/events (single event with all field validations) per event-api.md in apps/experiment_hub_web/test/experiment_hub_web/controllers/event_controller_test.exs
- [X] T095 [P] [US3] Write contract test for POST /v1/events/batch (batch up to 1000 events, partial success 207 response) in apps/experiment_hub_web/test/experiment_hub_web/controllers/event_controller_test.exs
- [X] T096 [P] [US3] Write property-based test with StreamData for event schema validation (fuzz required/optional fields) in apps/event_collector/test/event_collector/validation_test.exs
- [X] T097 [P] [US3] Write integration test for event deduplication: same idempotency_key persisted only once in apps/event_collector/test/event_collector/deduplication_integration_test.exs
- [X] T098 [P] [US3] Write integration test for Broadway pipeline: produce Kafka message → consume → validate → persist in apps/event_collector/test/event_collector/broadway/pipeline_integration_test.exs

### Implementation for User Story 3

- [X] T099 [US3] Create experiment_events_raw Ecto schema and migration with monthly range partitioning by inserted_at in apps/experiment_hub/lib/experiment_hub/events/experiment_event.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T100 [US3] Create initial monthly partition (experiment_events_raw_YYYY_MM) and partition management Oban job in apps/experiment_hub/priv/repo/migrations/
- [X] T101 [US3] Implement event validation module with all schema validation rules from event-api.md in apps/event_collector/lib/event_collector/validation/event_validator.ex
- [X] T102 [US3] Implement Kafka producer for writing validated events to `experimenthub.events.raw` topic in apps/event_collector/lib/event_collector/kafka/producer.ex
- [X] T103 [US3] Implement Broadway pipeline for inbound event ingestion from `experimenthub.events.inbound` topic in apps/event_collector/lib/event_collector/broadway/event_pipeline.ex
- [X] T104 [US3] Implement batch processor in Broadway pipeline: validate, deduplicate, persist batch to PostgreSQL in apps/event_collector/lib/event_collector/broadway/batch_processor.ex
- [X] T105 [US3] Implement event deduplication via UNIQUE(tenant_id, idempotency_key) index and ON CONFLICT DO NOTHING in apps/event_collector/lib/event_collector/broadway/batch_processor.ex
- [X] T106 [US3] Implement bot detection tagging based on user-agent matching in apps/event_collector/lib/event_collector/validation/bot_detector.ex
- [X] T107 [US3] Implement backpressure handling: return 503 with Retry-After when Kafka unavailable and buffer full in apps/event_collector/lib/event_collector/broadway/event_pipeline.ex
- [X] T108 [US3] Implement EventController with POST /v1/events and POST /v1/events/batch endpoints per event-api.md in apps/experiment_hub_web/lib/experiment_hub_web/controllers/event_controller.ex
- [X] T109 [US3] Implement post-conclusion event tagging (is_post_conclusion flag) when experiment status is concluded in apps/event_collector/lib/event_collector/validation/event_validator.ex
- [X] T110 [US3] Add event collection routes to Phoenix router in apps/experiment_hub_web/lib/experiment_hub_web/router.ex

**Checkpoint**: Events can be ingested via REST API, validated, deduplicated, and persisted via Broadway + Kafka. User Story 3 is independently testable.

---

## Phase 6: User Story 4 — Platform Computes Statistical Results (Priority: P1)

**Goal**: Statistical engine computes frequentist analysis (z-test, Welch's t-test) with p-values, confidence intervals, effect sizes, and sequential analysis. Data pipeline background workers aggregate raw events into daily rollups.

**Independent Test**: Ingest 10K events per variant with known conversion rates, call POST /stats/v1/analyze/{experiment_id}, verify p-value, CI, and effect size match scipy reference within 0.1%.

### Tests for User Story 4 ⚠️

> **Write these tests FIRST — ensure they FAIL before implementation (Article III)**

- [X] T111 [P] [US4] Write property-based test with hypothesis: frequentist z-test results match scipy.stats.proportions_ztest within 0.1% in statistical_engine/tests/test_frequentist.py
- [X] T112 [P] [US4] Write property-based test with hypothesis: Welch's t-test results match scipy.stats.ttest_ind within 0.1% in statistical_engine/tests/test_frequentist.py
- [X] T113 [P] [US4] Write test for O'Brien-Fleming sequential analysis alpha-spending function in statistical_engine/tests/test_sequential.py
- [X] T114 [P] [US4] Write test for sample size/power calculation matching analytical formulas in statistical_engine/tests/test_power.py
- [X] T115 [P] [US4] Write contract test for POST /stats/v1/analyze/{experiment_id} API response structure per statistical-api.md in statistical_engine/tests/test_api.py
- [X] T116 [P] [US4] Write contract test for POST /stats/v1/power (sample size calculation endpoint) in statistical_engine/tests/test_api.py
- [X] T117 [P] [US4] Write integration test for data pipeline background workers: raw events ? Kafka consumer ? daily rollup aggregation in data_pipeline/tests/test_aggregation_integration.py
- [X] T118 [P] [US4] Write test for insufficient data warning when sample size below minimum in statistical_engine/tests/test_frequentist.py
- [X] T321 [P] [US4] Write reproducibility test (FR-030): run identical analysis twice on same input data and configuration, assert all output values (p-value, CI, effect size) match within 0.1% in statistical_engine/tests/test_reproducibility.py

### Implementation for User Story 4

- [X] T119 [P] [US4] Create experiment_results_daily Ecto schema and migration with monthly range partitioning by date in apps/experiment_hub/lib/experiment_hub/metrics/experiment_result_daily.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T120 [P] [US4] Create statistical_analyses Ecto schema and migration (analysis_type, methodology, parameters, results JSONB) in apps/experiment_hub/lib/experiment_hub/metrics/statistical_analysis.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T121 [US4] Create FastAPI application entry point with CORS, logging, and internal auth middleware in statistical_engine/src/api/main.py
- [X] T122 [P] [US4] Implement Pydantic request/response models for analysis endpoints per statistical-api.md in statistical_engine/src/models/analysis.py
- [X] T123 [P] [US4] Implement Pydantic request/response models for power calculation endpoint in statistical_engine/src/models/power.py
- [X] T124 [US4] Implement frequentist z-test for proportions (p-value, 95% CI, effect size, achieved power) in statistical_engine/src/core/frequentist.py
- [X] T125 [US4] Implement Welch's t-test for continuous metrics (p-value, 95% CI, Cohen's d) in statistical_engine/src/core/frequentist.py
- [X] T126 [US4] Implement O'Brien-Fleming alpha-spending function for sequential analysis in statistical_engine/src/core/sequential.py
- [X] T127 [US4] Implement sample size and power calculations in statistical_engine/src/core/power.py
- [X] T128 [US4] Implement analysis API route: POST /stats/v1/analyze/{experiment_id} that orchestrates frequentist analysis in statistical_engine/src/api/routes/analysis.py
- [X] T129 [US4] Implement cached results retrieval: GET /stats/v1/analyze/{experiment_id}/results in statistical_engine/src/api/routes/analysis.py
- [X] T130 [US4] Implement power calculation route: POST /stats/v1/power in statistical_engine/src/api/routes/power.py
- [X] T131 [US4] Implement health check endpoint: GET /stats/v1/health in statistical_engine/src/api/routes/health.py
- [X] T132 [US4] Implement data_pipeline background worker Kafka consumer for `experimenthub.events.raw` topic in data_pipeline/src/consumers/event_consumer.py
- [X] T133 [US4] Implement daily rollup aggregation: raw events → experiment_results_daily (sample_size, conversions, sum_value, sum_squared_value) in data_pipeline/src/aggregators/daily_rollup.py
- [X] T134 [US4] Implement data cleaning and bot event filtering in data_pipeline/src/transforms/event_filter.py
- [X] T135 [US4] Implement Oban job in Elixir that triggers statistical analysis via HTTP call to statistical engine on a configurable schedule; propagate W3C Trace Context headers (traceparent/tracestate) on all outbound HTTP requests in apps/experiment_hub/lib/experiment_hub/workers/analysis_worker.ex
- [X] T136 [US4] Implement ResultsController proxying analysis results from statistical engine to dashboard; forward W3C Trace Context headers on outbound requests; map statistical engine `overall_status` to `has_sufficient_data` boolean in management API response (per management-api.md contract); include sequential analysis data in apps/experiment_hub_web/lib/experiment_hub_web/controllers/results_controller.ex

**Checkpoint**: Raw events are aggregated into daily rollups by the data pipeline background workers (not a core service � Constitution v1.0.1 Article I). Statistical engine computes frequentist results with sequential analysis. User Story 4 is independently testable.

---

## Phase 7: User Story 5 — PM Views Experiment Dashboard with Results (Priority: P1)

**Goal**: React dashboard showing experiment list (filterable by status), experiment detail with variant performance table, CI chart, cumulative conversion-over-time chart, and near-real-time updates via Phoenix Channels.

**Independent Test**: Load dashboard with a running experiment that has accumulated data; verify list renders, detail page shows variant table, CI chart, and time-series chart correctly.

### Tests for User Story 5 ⚠️

> **Write these tests FIRST — ensure they FAIL before implementation (Article III)**

- [X] T137 [P] [US5] Write Vitest unit test for ExperimentList component (renders experiment rows with status badges, handles empty state) in dashboard/tests/unit/ExperimentList.test.tsx
- [X] T138 [P] [US5] Write Vitest unit test for ExperimentDetail component (renders variant table, significance status, recommendation) in dashboard/tests/unit/ExperimentDetail.test.tsx
- [X] T139 [P] [US5] Write Vitest unit test for ConfidenceIntervalChart component (renders CI bars correctly) in dashboard/tests/unit/ConfidenceIntervalChart.test.tsx
- [X] T140 [P] [US5] Write Vitest unit test for ConversionOverTimeChart component (renders time-series line chart) in dashboard/tests/unit/ConversionOverTimeChart.test.tsx
- [X] T141 [P] [US5] Write Playwright E2E test for full flow: login → experiments list → click experiment → see results in dashboard/tests/e2e/experiment-results.spec.ts

### Implementation for User Story 5

- [X] T142 [US5] Set up React Router with page layout (sidebar navigation, header with tenant info) in dashboard/src/App.tsx and dashboard/src/pages/Layout.tsx
- [X] T143 [US5] Implement typed API client with fetch wrapper, auth headers, and error handling in dashboard/src/lib/api.ts
- [X] T144 [US5] Implement shared TypeScript types matching Management API response schemas in dashboard/src/lib/types.ts
- [X] T145 [US5] Implement AuthContext with JWT login/logout and token management in dashboard/src/contexts/AuthContext.tsx
- [X] T146 [US5] Implement TenantContext for current tenant info in dashboard/src/contexts/TenantContext.tsx
- [X] T147 [US5] Implement TanStack Query hooks for experiments: useExperiments, useExperiment, useCreateExperiment, useUpdateExperiment in dashboard/src/hooks/useExperiments.ts
- [X] T148 [US5] Implement TanStack Query hooks for results: useExperimentResults in dashboard/src/hooks/useResults.ts
- [X] T149 [US5] Implement ExperimentList page component with status filter, search, sort, and pagination in dashboard/src/pages/ExperimentListPage.tsx
- [X] T150 [US5] Implement ExperimentList table component with status badges (draft/running/paused/concluded) in dashboard/src/components/experiments/ExperimentList.tsx
- [X] T151 [US5] Implement ExperimentDetail page component with tabbed layout (Overview, Results, Settings) in dashboard/src/pages/ExperimentDetailPage.tsx
- [X] T152 [US5] Implement variant performance table component (variant name, sample size, conversions, rate, CI) in dashboard/src/components/experiments/VariantTable.tsx
- [X] T153 [US5] Implement ConfidenceIntervalChart using Recharts (horizontal bar chart with CI whiskers) in dashboard/src/components/charts/ConfidenceIntervalChart.tsx
- [X] T154 [US5] Implement ConversionOverTimeChart using Recharts (multi-line time-series) in dashboard/src/components/charts/ConversionOverTimeChart.tsx
- [X] T155 [US5] Implement StatisticalSummary component showing p-value, significance status, recommendation text in dashboard/src/components/experiments/StatisticalSummary.tsx
- [X] T156 [US5] Implement experiment creation wizard page (step 1: hypothesis, step 2: variants, step 3: traffic, step 4: metrics) in dashboard/src/pages/CreateExperimentPage.tsx
- [X] T157 [US5] Implement Phoenix Channels client wrapper in dashboard/src/lib/ws.ts
- [X] T158 [US5] Implement WebSocketContext connecting to Phoenix Channels for live experiment updates in dashboard/src/contexts/WebSocketContext.tsx
- [X] T159 [US5] Implement near-real-time result refresh: subscribe to experiment channel, auto-refetch results when new analysis available in dashboard/src/hooks/useResults.ts
- [X] T160 [US5] Implement Phoenix Channel for experiment updates (join experiment:* topic, broadcast on result update) in apps/experiment_hub_web/lib/experiment_hub_web/channels/experiment_channel.ex
- [X] T161 [US5] Configure Phoenix Channel socket and topic routing in apps/experiment_hub_web/lib/experiment_hub_web/channels/user_socket.ex
- [X] T323 [US5] Implement SampleSizeWarning component: render "Insufficient sample size � results are preliminary" banner when statistical engine returns `has_sufficient_data: false` (FR-029) in dashboard/src/components/experiments/SampleSizeWarning.tsx
- [X] T324 [P] [US5] Write Vitest unit test for SampleSizeWarning component (renders warning when insufficient, hidden when sufficient) in dashboard/tests/unit/SampleSizeWarning.test.tsx

**Checkpoint**: Dashboard is functional with experiment list, detail view, charts, sample size warnings, and live updates. User Story 5 is independently testable.

---

## Phase 8: User Story 6 — PM Stops Experiment and Records Decision (Priority: P1)

**Goal**: PM can stop (conclude) a running experiment, record the decision (ship variant / revert / inconclusive) with rationale. Pause/resume is supported. All actions are recorded in an immutable audit trail.

**Independent Test**: Conclude a running experiment via POST /api/v1/experiments/:id/conclude, verify experiment transitions to "concluded" with decision recorded. Check audit log contains the action.

### Tests for User Story 6 ⚠️

> **Write these tests FIRST — ensure they FAIL before implementation (Article III)**

- [X] T162 [P] [US6] Write unit test for conclude transition with decision/rationale recording in apps/experiment_hub/test/experiment_hub/experiments/conclude_test.exs
- [X] T163 [P] [US6] Write contract test for POST /api/v1/experiments/:id/conclude endpoint in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_controller_test.exs
- [X] T164 [P] [US6] Write contract test for POST /api/v1/experiments/:id/pause endpoint in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_controller_test.exs
- [X] T165 [P] [US6] Write unit test for audit log immutability (append-only, no update/delete) in apps/experiment_hub/test/experiment_hub/audit/audit_test.exs
- [X] T166 [P] [US6] Write integration test: create → launch → pause → resume → conclude → verify full audit trail in apps/experiment_hub/test/experiment_hub/audit/audit_integration_test.exs

### Implementation for User Story 6

- [X] T167 [US6] Create audit_logs Ecto schema and migration with monthly range partitioning by inserted_at, REVOKE UPDATE/DELETE from app role in apps/experiment_hub/lib/experiment_hub/audit/audit_log.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T168 [US6] Implement Audit context: create_audit_log/1 (append-only), list_audit_logs/1 with filters in apps/experiment_hub/lib/experiment_hub/audit.ex
- [X] T169 [US6] Implement conclude experiment action: transition to concluded, record decision + rationale + concluded_by + timestamp in apps/experiment_hub/lib/experiment_hub/experiments.ex
- [X] T170 [US6] Implement audit log emission on all experiment state transitions and configuration changes in apps/experiment_hub/lib/experiment_hub/experiments.ex
- [X] T171 [US6] Implement lifecycle event publishing to Kafka topic `experimenthub.lifecycle` on state transitions in apps/experiment_hub/lib/experiment_hub/experiments/lifecycle_publisher.ex
- [X] T172 [US6] Implement conclude experiment UI: stop button, decision modal (ship/revert/inconclusive), rationale text field in dashboard/src/components/experiments/ConcludeModal.tsx
- [X] T173 [US6] Implement pause/resume buttons on running experiment detail page in dashboard/src/components/experiments/ExperimentActions.tsx
- [X] T174 [US6] Implement concluded experiment view showing decision, rationale, who decided, and when in dashboard/src/components/experiments/ConclusionSummary.tsx

**Checkpoint**: Experiments can be paused, resumed, and concluded with decisions. Full audit trail records all actions. User Story 6 completes the core P1 experimentation loop.

---

## Phase 9: User Story 7 — PM Creates Multivariate Test (Priority: P2)

**Goal**: Support experiments with 3-20 variants and custom traffic splits. Statistical engine applies multiple comparison corrections (Bonferroni or Holm-Šidák) automatically.

**Independent Test**: Create 4-variant experiment, verify assignments distribute correctly, confirm pairwise comparison results include adjusted p-values.

### Tests for User Story 7 ⚠️

- [X] T175 [P] [US7] Write unit test for 3-20 variant creation with uneven traffic splits (e.g., 50/20/20/10) in apps/experiment_hub/test/experiment_hub/experiments/multivariate_test.exs
- [X] T176 [P] [US7] Write property-based test with hypothesis: Bonferroni and Holm-Šidák corrections produce correct adjusted p-values in statistical_engine/tests/test_multiple_comparisons.py
- [X] T177 [P] [US7] Write integration test for multivariate assignment distribution across 4 variants in apps/experiment_hub/test/experiment_hub/assignments/multivariate_integration_test.exs

### Implementation for User Story 7

- [X] T178 [US7] Extend experiment creation validation to accept 3-20 variants with configurable uneven traffic splits in apps/experiment_hub/lib/experiment_hub/experiments/variant_validator.ex
- [X] T179 [US7] Implement Bonferroni and Holm-Šidák multiple comparison corrections in statistical_engine/src/core/frequentist.py
- [X] T180 [US7] Implement pairwise comparison analysis for 3+ variants in statistical_engine/src/core/frequentist.py
- [X] T181 [US7] Update analysis API route to include pairwise comparisons and adjusted p-values when variant_count > 2 in statistical_engine/src/api/routes/analysis.py
- [X] T182 [US7] Update experiment creation wizard to support adding 3+ variants with drag-and-drop traffic allocation in dashboard/src/pages/CreateExperimentPage.tsx
- [X] T183 [US7] Update results display to show pairwise comparison table with adjusted p-values in dashboard/src/components/experiments/PairwiseComparisonTable.tsx

**Checkpoint**: Multivariate experiments (3-20 variants) fully functional with corrected statistical analysis.

---

## Phase 10: User Story 8 — PM Configures Experiment Targeting Rules (Priority: P2)

**Goal**: Targeting rules based on user attributes (country, device, plan) with AND/OR logic. Only eligible users receive assignments; non-matching users get control.

**Independent Test**: Create targeting rule "country = US", request assignment for US user (enrolled) and GB user (not enrolled).

### Tests for User Story 8 ⚠️

- [X] T184 [P] [US8] Write unit test for targeting rule evaluation with all operators (eq, neq, contains, in, gt, lt) in apps/experiment_hub/test/experiment_hub/targeting/rule_engine_test.exs
- [X] T185 [P] [US8] Write unit test for compound targeting rules with AND/OR logic groups in apps/experiment_hub/test/experiment_hub/targeting/rule_engine_test.exs
- [X] T186 [P] [US8] Write contract test for targeting rules CRUD endpoints in apps/experiment_hub_web/test/experiment_hub_web/controllers/targeting_rule_controller_test.exs
- [X] T187 [P] [US8] Write integration test: targeting rule + assignment flow (eligible vs non-eligible users) in apps/experiment_hub/test/experiment_hub/targeting/assignment_integration_test.exs

### Implementation for User Story 8

- [X] T188 [P] [US8] Create targeting_rules Ecto schema and migration (attribute, operator, value JSONB, logic_group, target_type) in apps/experiment_hub/lib/experiment_hub/targeting/targeting_rule.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T189 [P] [US8] Create segments Ecto schema and migration (name, rules JSONB) in apps/experiment_hub/lib/experiment_hub/targeting/segment.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T190 [US8] Implement Targeting context with CRUD for targeting rules and segments in apps/experiment_hub/lib/experiment_hub/targeting.ex
- [X] T191 [US8] Implement targeting rule engine: evaluate user attributes against rules with AND/OR logic in apps/experiment_hub/lib/experiment_hub/targeting/rule_engine.ex
- [X] T192 [US8] Integrate targeting evaluation into assignment flow: check rules before assigning variant, return control for non-matching users in apps/experiment_hub/lib/experiment_hub/assignments.ex
- [X] T193 [US8] Implement existing assignment preservation: users with prior assignment keep it even if targeting rules change in apps/experiment_hub/lib/experiment_hub/assignments.ex
- [X] T194 [US8] Implement TargetingRuleController (CRUD endpoints) per management-api.md in apps/experiment_hub_web/lib/experiment_hub_web/controllers/targeting_rule_controller.ex
- [X] T195 [US8] Implement targeting rules UI: rule builder with attribute/operator/value inputs and logic group management in dashboard/src/components/experiments/TargetingRuleBuilder.tsx
- [X] T196 [US8] Add targeting rule routes to Phoenix router in apps/experiment_hub_web/lib/experiment_hub_web/router.ex
- [X] T319 [US8] Implement percentage-based targeting: after rule evaluation, apply `hash(user_id + experiment_key) % 10000 < target_percentage` to sample only the configured percentage of eligible users (FR-033) in apps/experiment_hub/lib/experiment_hub/targeting/rule_engine.ex
- [X] T320 [P] [US8] Write unit test for percentage-based targeting: verify ~30% enrollment rate when configured at 30%, combined with attribute rules in apps/experiment_hub/test/experiment_hub/targeting/percentage_targeting_test.exs

**Checkpoint**: Targeting rules can be configured and evaluated at assignment time. Users not matching rules are excluded. Percentage-based targeting (FR-033) supported.

---

## Phase 11: User Story 9 — Analyst Configures Guardrail Metrics (Priority: P2)

**Goal**: Guardrail metrics with breach thresholds automatically pause experiments when degraded, preventing harm.

**Independent Test**: Configure guardrail "error_rate > 5%", ingest events exceeding threshold, verify experiment auto-pauses.

### Tests for User Story 9 ⚠️

- [X] T197 [P] [US9] Write unit test for guardrail threshold breach detection (above/below direction) in apps/experiment_hub/test/experiment_hub/metrics/guardrail_test.exs
- [X] T198 [P] [US9] Write integration test: configure guardrail → ingest breaching events → analysis detects breach → experiment auto-pauses in apps/experiment_hub/test/experiment_hub/metrics/guardrail_integration_test.exs

### Implementation for User Story 9

- [X] T199 [US9] Implement guardrail evaluation in statistical engine analysis cycle: check each guardrail metric against threshold in statistical_engine/src/core/frequentist.py
- [X] T200 [US9] Return guardrail breach status in analysis response (is_breached, breach_magnitude, recommendation) per statistical-api.md in statistical_engine/src/api/routes/analysis.py
- [X] T201 [US9] Implement auto-pause Oban worker: when analysis detects guardrail breach, transition experiment to paused with breach reason in apps/experiment_hub/lib/experiment_hub/workers/guardrail_worker.ex
- [X] T202 [US9] Implement guardrail breach notification via audit log entry with breach details in apps/experiment_hub/lib/experiment_hub/workers/guardrail_worker.ex
- [X] T203 [US9] Add guardrail metric configuration UI in experiment settings (threshold input, direction selector) in dashboard/src/components/metrics/GuardrailConfig.tsx
- [X] T204 [US9] Update experiment detail page to show guardrail breach info when experiment is paused by guardrail in dashboard/src/components/experiments/GuardrailBreachAlert.tsx

**Checkpoint**: Guardrail metrics can be configured and automatically pause experiments on threshold breach.

---

## Phase 12: User Story 10 — PM Schedules Experiment Start/End Dates (Priority: P2)

**Goal**: Experiments auto-start and auto-end at scheduled dates via Oban background jobs.

**Independent Test**: Schedule experiment to start 1 minute in the future, verify it transitions to "running" automatically.

### Tests for User Story 10 ⚠️

- [X] T205 [P] [US10] Write unit test for scheduled start Oban worker (transitions draft→running at scheduled_start_at) in apps/experiment_hub/test/experiment_hub/workers/scheduler_test.exs
- [X] T206 [P] [US10] Write unit test for scheduled end Oban worker (transitions running→concluded at scheduled_end_at with reason "scheduled_end") in apps/experiment_hub/test/experiment_hub/workers/scheduler_test.exs

### Implementation for User Story 10

- [X] T207 [US10] Implement ScheduledStartWorker Oban job: query experiments with scheduled_start_at <= now() and status=draft, transition to running in apps/experiment_hub/lib/experiment_hub/workers/scheduled_start_worker.ex
- [X] T208 [US10] Implement ScheduledEndWorker Oban job: query experiments with scheduled_end_at <= now() and status=running, transition to concluded in apps/experiment_hub/lib/experiment_hub/workers/scheduled_end_worker.ex
- [X] T209 [US10] Configure Oban cron schedule for scheduled start/end workers (check every minute) in apps/experiment_hub/lib/experiment_hub/oban_config.ex
- [X] T210 [US10] Add scheduling date/time pickers to experiment creation/edit form in dashboard/src/components/experiments/ScheduleForm.tsx
- [X] T211 [US10] Display scheduled timeline on experiment detail page in dashboard/src/components/experiments/ScheduleTimeline.tsx

**Checkpoint**: Experiments can be scheduled to start and end automatically.

---

## Phase 13: User Story 11 — Analyst Views Bayesian Results Alongside Frequentist (Priority: P2)

**Goal**: Bayesian analysis (Beta-Binomial, Normal-Normal conjugate models) computing probability-to-be-best, credible intervals, and expected loss displayed alongside frequentist results.

**Independent Test**: Run analysis with sufficient data, verify Bayesian section shows probability-to-be-best and credible intervals alongside frequentist p-values.

### Tests for User Story 11 ⚠️

- [X] T212 [P] [US11] Write property-based test with hypothesis: Beta-Binomial conjugate posterior matches analytical formula in statistical_engine/tests/test_bayesian.py
- [X] T213 [P] [US11] Write property-based test with hypothesis: Normal-Normal conjugate posterior matches analytical formula in statistical_engine/tests/test_bayesian.py
- [X] T214 [P] [US11] Write test for probability-to-be-best via Thompson Sampling simulation convergence in statistical_engine/tests/test_bayesian.py
- [X] T215 [P] [US11] Write test for expected loss calculation in statistical_engine/tests/test_bayesian.py

### Implementation for User Story 11

- [X] T216 [US11] Implement Beta-Binomial conjugate analysis (posterior, credible interval) with weak prior Beta(1,1) in statistical_engine/src/core/bayesian.py
- [X] T217 [US11] Implement Normal-Normal conjugate analysis (posterior, credible interval) in statistical_engine/src/core/bayesian.py
- [X] T218 [US11] Implement probability-to-be-best via Thompson Sampling simulation (10K samples) in statistical_engine/src/core/bayesian.py
- [X] T219 [US11] Implement expected loss calculation per variant in statistical_engine/src/core/bayesian.py
- [X] T220 [US11] Integrate Bayesian analysis into POST /stats/v1/analyze/{experiment_id} response when config.analysis_types includes "bayesian" in statistical_engine/src/api/routes/analysis.py
- [X] T221 [US11] Implement BayesianResults component showing probability-to-be-best, credible interval, expected loss side-by-side with frequentist in dashboard/src/components/experiments/BayesianResults.tsx
- [X] T222 [US11] Update ExperimentDetail page to show dual methodology results tab in dashboard/src/pages/ExperimentDetailPage.tsx

**Checkpoint**: Both frequentist and Bayesian results displayed side-by-side on dashboard.

---

## Phase 14: User Story 12 — PM Adds Experiment to Mutual Exclusion Group (Priority: P3)

**Goal**: Mutual exclusion groups prevent users from being enrolled in multiple experiments within the same group. Layer-based assignment using group-level hashing.

**Independent Test**: Create two experiments in the same exclusion group, assign a user to one, verify they cannot be assigned to the other.

### Tests for User Story 12 ⚠️

- [X] T223 [P] [US12] Write unit test for mutual exclusion assignment logic (user in experiment A → not enrolled in experiment B in same group) in apps/experiment_hub/test/experiment_hub/assignments/mutual_exclusion_test.exs
- [X] T224 [P] [US12] Write integration test for traffic allocation within mutual exclusion group in apps/experiment_hub/test/experiment_hub/assignments/mutual_exclusion_integration_test.exs
- [X] T225 [P] [US12] Write contract test for experiment groups CRUD endpoints in apps/experiment_hub_web/test/experiment_hub_web/controllers/experiment_group_controller_test.exs

### Implementation for User Story 12

- [X] T226 [P] [US12] Create experiment_groups Ecto schema and migration (name, description) in apps/experiment_hub/lib/experiment_hub/experiments/experiment_group.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T227 [US12] Implement ExperimentGroups context with CRUD and member experiment management in apps/experiment_hub/lib/experiment_hub/experiments/experiment_groups.ex
- [X] T228 [US12] Implement layer-based assignment for mutual exclusion: hash(layer_id + user_id) → experiment slot → variant in apps/experiment_hub/lib/experiment_hub/assignments/mutual_exclusion.ex
- [X] T229 [US12] Integrate mutual exclusion logic into assignment flow: check group membership before standard assignment in apps/experiment_hub/lib/experiment_hub/assignments.ex
- [X] T230 [US12] Implement traffic release when experiment in group concludes in apps/experiment_hub/lib/experiment_hub/experiments/experiment_groups.ex
- [X] T231 [US12] Implement ExperimentGroupController (CRUD endpoints) per management-api.md in apps/experiment_hub_web/lib/experiment_hub_web/controllers/experiment_group_controller.ex
- [X] T232 [US12] Add mutual exclusion group selector to experiment creation form in dashboard/src/components/experiments/MutualExclusionGroupSelect.tsx

**Checkpoint**: Mutual exclusion groups prevent cross-experiment enrollment for the same user.

---

## Phase 15: User Story 13 — Manager Reviews Experiment History with Audit Trail (Priority: P3)

**Goal**: Complete audit trail view showing who did what, when, and what changed. Filterable by date range, action type, and actor.

**Independent Test**: Perform create → modify → launch → pause → conclude on an experiment, verify all actions appear in audit log with correct actor, timestamp, and before/after state.

### Tests for User Story 13 ⚠️

- [X] T233 [P] [US13] Write integration test for audit trail completeness across experiment lifecycle in apps/experiment_hub/test/experiment_hub/audit/completeness_integration_test.exs
- [X] T234 [P] [US13] Write contract test for GET /api/v1/audit-logs with filters (resource_type, action, date range, actor_id) in apps/experiment_hub_web/test/experiment_hub_web/controllers/audit_log_controller_test.exs

### Implementation for User Story 13

- [X] T235 [US13] Implement AuditLogController with GET /api/v1/audit-logs and query filters per management-api.md in apps/experiment_hub_web/lib/experiment_hub_web/controllers/audit_log_controller.ex
- [X] T236 [US13] Implement audit trail page in dashboard with chronological event list and filters in dashboard/src/pages/AuditLogPage.tsx
- [X] T237 [US13] Implement audit log detail component showing before/after state diff in dashboard/src/components/admin/AuditLogEntry.tsx
- [X] T238 [US13] Implement TanStack Query hooks for audit logs: useAuditLogs with filter params in dashboard/src/hooks/useAuditLogs.ts

**Checkpoint**: Full audit trail viewable and filterable in dashboard.

---

## Phase 16: User Story 14 — Admin Manages Tenants, API Keys, and Permissions (Priority: P3)

**Goal**: Platform admin can create tenants, generate/revoke API keys, and manage user roles (viewer, editor, admin). Data is fully isolated per tenant.

**Independent Test**: Create tenant, generate API key, create users with different roles, verify each role has correct access level.

### Tests for User Story 14 ⚠️

- [X] T239 [P] [US14] Write contract test for tenant CRUD endpoints (POST, GET, PUT) in apps/experiment_hub_web/test/experiment_hub_web/controllers/tenant_controller_test.exs
- [X] T240 [P] [US14] Write contract test for API key management endpoints (POST, GET, DELETE) in apps/experiment_hub_web/test/experiment_hub_web/controllers/api_key_controller_test.exs
- [X] T241 [P] [US14] Write contract test for user management endpoints (POST, GET, PUT, DELETE) in apps/experiment_hub_web/test/experiment_hub_web/controllers/user_controller_test.exs
- [X] T242 [P] [US14] Write integration test for RBAC enforcement: viewer cannot create, editor cannot manage keys, admin has full access in apps/experiment_hub_web/test/experiment_hub_web/controllers/rbac_integration_test.exs

### Implementation for User Story 14

- [X] T243 [US14] Implement TenantController (POST, GET, PUT) for superadmin tenant management in apps/experiment_hub_web/lib/experiment_hub_web/controllers/tenant_controller.ex
- [X] T244 [US14] Implement ApiKeyController (POST, GET, DELETE) for API key generation and revocation in apps/experiment_hub_web/lib/experiment_hub_web/controllers/api_key_controller.ex
- [X] T245 [US14] Implement UserController (POST, GET, PUT, DELETE) for user CRUD within tenant in apps/experiment_hub_web/lib/experiment_hub_web/controllers/user_controller.ex
- [X] T246 [US14] Implement session-based login endpoint (POST /api/v1/auth/login) returning JWT in apps/experiment_hub_web/lib/experiment_hub_web/controllers/auth_controller.ex
- [X] T247 [US14] Implement admin settings pages: tenant info, API key management, user management in dashboard/src/pages/AdminSettingsPage.tsx
- [X] T248 [US14] Implement API key generation UI (show key once on creation, copy-to-clipboard) in dashboard/src/components/admin/ApiKeyManager.tsx
- [X] T249 [US14] Implement user management UI (invite user, assign role, remove user) in dashboard/src/components/admin/UserManager.tsx
- [X] T250 [US14] Add admin routes to Phoenix router in apps/experiment_hub_web/lib/experiment_hub_web/router.ex

**Checkpoint**: Tenants, API keys, and users can be fully managed with RBAC enforcement.

---

## Phase 17: User Story 15 — Analyst Exports Experiment Results (Priority: P3)

**Goal**: Export experiment results in CSV, JSON, and Excel formats for external analysis.

**Independent Test**: Export a concluded experiment's results in each format, verify exported file contains complete, accurate data matching the defined columns.

### Tests for User Story 15 ⚠️

- [X] T251 [P] [US15] Write contract test for GET /api/v1/experiments/:id/results/export?format=csv (verify CSV columns and data) in apps/experiment_hub_web/test/experiment_hub_web/controllers/export_controller_test.exs
- [X] T252 [P] [US15] Write contract test for GET /api/v1/experiments/:id/results/export?format=json (verify JSON structure) in apps/experiment_hub_web/test/experiment_hub_web/controllers/export_controller_test.exs
- [X] T253 [P] [US15] Write contract test for GET /api/v1/experiments/:id/results/export?format=xlsx (verify Excel binary response) in apps/experiment_hub_web/test/experiment_hub_web/controllers/export_controller_test.exs

### Implementation for User Story 15

- [X] T254 [US15] Implement CSV export serializer (columns: variant, sample_size, conversions, conversion_rate, ci_lower, ci_upper, p_value) in apps/experiment_hub/lib/experiment_hub/exports/csv_exporter.ex
- [X] T255 [US15] Implement JSON export serializer (full analysis with frequentist + Bayesian results) in apps/experiment_hub/lib/experiment_hub/exports/json_exporter.ex
- [X] T256 [US15] Implement Excel export serializer with multiple sheets (summary, per-variant details, daily time series) in apps/experiment_hub/lib/experiment_hub/exports/xlsx_exporter.ex
- [X] T257 [US15] Implement ExportController with GET /api/v1/experiments/:id/results/export endpoint and format parameter in apps/experiment_hub_web/lib/experiment_hub_web/controllers/export_controller.ex
- [X] T258 [US15] Add export buttons (CSV, JSON, Excel) to experiment detail results tab in dashboard/src/components/experiments/ExportButtons.tsx

**Checkpoint**: Experiment results exportable in CSV, JSON, and Excel formats.

---

## Phase 18: User Story 16 — Engineer Uses SDK for Feature Flags (Priority: P4)

**Goal**: Feature flags with on/off states, sharing the same assignment infrastructure as experiments. Evaluated via GET /v1/flags/{flag_key}.

**Independent Test**: Create a feature flag, evaluate it for different users, verify correct on/off state.

### Tests for User Story 16 ⚠️

- [X] T259 [P] [US16] Write unit test for feature flag CRUD (create, enable, disable) in apps/experiment_hub/test/experiment_hub/feature_flags/feature_flag_test.exs
- [X] T260 [P] [US16] Write contract test for feature flag CRUD endpoints (POST, GET, PUT, DELETE) in apps/experiment_hub_web/test/experiment_hub_web/controllers/feature_flag_controller_test.exs
- [X] T261 [P] [US16] Write contract test for GET /v1/flags/{flag_key} evaluation endpoint per assignment-api.md in apps/experiment_hub_web/test/experiment_hub_web/controllers/flag_controller_test.exs
- [X] T262 [P] [US16] Write unit test for feature flag caching in Redis (flag:{tenant_id}:{flag_key} key pattern) in apps/experiment_hub/test/experiment_hub/feature_flags/cache_test.exs

### Implementation for User Story 16

- [X] T263 [US16] Create feature_flags Ecto schema and migration (key, name, enabled, rollout_percentage, version) in apps/experiment_hub/lib/experiment_hub/feature_flags/feature_flag.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T264 [US16] Implement FeatureFlags context with CRUD: create, list, get, update, delete in apps/experiment_hub/lib/experiment_hub/feature_flags.ex
- [X] T265 [US16] Implement feature flag evaluation logic: global enabled check → rollout percentage check using MurmurHash3 in apps/experiment_hub/lib/experiment_hub/feature_flags/evaluator.ex
- [X] T266 [US16] Implement Redis caching for feature flag config (flag:{tenant_id}:{flag_key}) with 5-min TTL in apps/experiment_hub/lib/experiment_hub/feature_flags/flag_cache.ex
- [X] T267 [US16] Implement FlagController with GET /v1/flags/{flag_key} endpoint per assignment-api.md in apps/experiment_hub_web/lib/experiment_hub_web/controllers/flag_controller.ex
- [X] T268 [US16] Implement FeatureFlagController for management CRUD endpoints (POST, GET, PUT, DELETE) per management-api.md in apps/experiment_hub_web/lib/experiment_hub_web/controllers/feature_flag_controller.ex
- [X] T269 [US16] Implement feature flag management page in dashboard (list, create, edit, toggle on/off) in dashboard/src/pages/FeatureFlagsPage.tsx
- [X] T270 [US16] Implement feature flag list and detail components in dashboard/src/components/flags/FeatureFlagList.tsx and dashboard/src/components/flags/FeatureFlagDetail.tsx
- [X] T271 [US16] Add feature flag routes to Phoenix router and dashboard navigation in apps/experiment_hub_web/lib/experiment_hub_web/router.ex

**Checkpoint**: Feature flags can be created, managed, evaluated, and cached via the same infrastructure as experiments.

---

## Phase 19: User Story 17 — PM Creates Percentage-Based Rollout (Priority: P4)

**Goal**: Gradual percentage-based feature rollout (5% → 25% → 50% → 100%) with monotonic guarantee — increasing percentage only adds users, never removes.

**Independent Test**: Create rollout at 5%, verify ~5% of users get feature. Increase to 25%, verify all previous users still have feature.

### Tests for User Story 17 ⚠️

- [X] T272 [P] [US17] Write property-based test with StreamData: monotonic rollout guarantee — user with flag "on" at 5% still has "on" at 25%, 50%, 100% in apps/experiment_hub/test/experiment_hub/feature_flags/monotonic_rollout_test.exs
- [X] T273 [P] [US17] Write integration test: rollout at 5% → verify ~5% rate → ramp to 50% → verify ~50% rate in apps/experiment_hub/test/experiment_hub/feature_flags/rollout_integration_test.exs

### Implementation for User Story 17

- [X] T274 [US17] Implement monotonic rollout logic: hash(flag_key + user_id) % 10000 < rollout_percentage ensures users only added, never removed in apps/experiment_hub/lib/experiment_hub/feature_flags/evaluator.ex
- [X] T275 [US17] Add rollout percentage slider UI to feature flag management in dashboard/src/components/flags/RolloutSlider.tsx
- [X] T276 [US17] Implement rollout history timeline showing percentage changes over time in dashboard/src/components/flags/RolloutHistory.tsx

**Checkpoint**: Percentage-based rollouts are monotonic and configurable via the dashboard.

---

## Phase 20: User Story 18 — Engineer Gets Feature Flag with Targeting Rules (Priority: P4)

**Goal**: Feature flags support the same targeting rule engine as experiments to restrict flags to specific user segments.

**Independent Test**: Create a flag with rule "plan = enterprise AND country = US", evaluate for matching user (on) and non-matching user (off).

### Tests for User Story 18 ⚠️

- [X] T277 [P] [US18] Write unit test for feature flag targeting rule evaluation (same engine as experiments) in apps/experiment_hub/test/experiment_hub/feature_flags/targeting_test.exs
- [X] T278 [P] [US18] Write integration test: flag with targeting rule → evaluate matching and non-matching users in apps/experiment_hub/test/experiment_hub/feature_flags/targeting_integration_test.exs

### Implementation for User Story 18

- [X] T279 [US18] Integrate targeting rule engine with feature flag evaluation (reuse targeting/rule_engine.ex) in apps/experiment_hub/lib/experiment_hub/feature_flags/evaluator.ex
- [X] T280 [US18] Add targeting_rules support to feature flag CRUD (target_type = 'feature_flag') in apps/experiment_hub/lib/experiment_hub/feature_flags.ex
- [X] T281 [US18] Add targeting rule configuration UI to feature flag management page in dashboard/src/components/flags/FlagTargetingRules.tsx

**Checkpoint**: Feature flags support the same targeting rules as experiments. P4 feature flags fully complete.

---

## Phase 21: User Story 19 — Analyst Views Platform-Wide Dashboard (Priority: P5)

**Goal**: Platform-wide analytics dashboard: active experiments count, concluded this month, average duration, statistical power distribution.

**Independent Test**: With experiments in various states, verify dashboard metrics aggregate correctly.

### Tests for User Story 19 ⚠️

- [X] T282 [P] [US19] Write unit test for platform analytics aggregation queries in apps/experiment_hub/test/experiment_hub/analytics/platform_analytics_test.exs
- [X] T283 [P] [US19] Write Vitest component test for PlatformDashboard in dashboard/tests/unit/PlatformDashboard.test.tsx

### Implementation for User Story 19

- [X] T284 [US19] Implement Analytics context with platform-wide aggregation queries (active count, concluded this month, avg duration, power distribution) in apps/experiment_hub/lib/experiment_hub/analytics.ex
- [X] T285 [US19] Implement AnalyticsController with GET /api/v1/analytics/platform endpoint in apps/experiment_hub_web/lib/experiment_hub_web/controllers/analytics_controller.ex
- [X] T286 [US19] Implement PlatformDashboard page with summary cards and power distribution histogram in dashboard/src/pages/PlatformDashboardPage.tsx
- [X] T287 [US19] Implement PowerDistributionChart component using Recharts (histogram) in dashboard/src/components/charts/PowerDistributionChart.tsx

**Checkpoint**: Platform-wide analytics visible on dashboard.

---

## Phase 22: User Story 20 — Analyst Creates Custom Metric Definitions (Priority: P5)

**Goal**: Custom metric definitions: ratio metrics (conversions/sessions), funnel metrics (multi-step conversion), composite metrics.

**Independent Test**: Define ratio metric "revenue_per_user", attach to experiment, verify results compute correctly using the custom definition.

### Tests for User Story 20 ⚠️

- [X] T288 [P] [US20] Write unit test for ratio metric computation in statistical_engine/tests/test_custom_metrics.py
- [X] T289 [P] [US20] Write unit test for funnel metric step-by-step computation in statistical_engine/tests/test_custom_metrics.py
- [X] T290 [P] [US20] Write integration test: custom metric definition → attach to experiment → compute results in statistical_engine/tests/test_custom_metrics_integration.py

### Implementation for User Story 20

- [X] T291 [US20] Implement ratio metric computation (numerator event / denominator event) in statistical_engine/src/core/custom_metrics.py
- [X] T292 [US20] Implement funnel metric computation (ordered step conversion rates) in statistical_engine/src/core/custom_metrics.py
- [X] T293 [US20] Integrate custom metric computation into analysis pipeline in statistical_engine/src/api/routes/analysis.py
- [X] T294 [US20] Implement custom metric definition form (type selector, event mapping) in dashboard/src/components/metrics/CustomMetricForm.tsx
- [X] T295 [US20] Implement FunnelChart component for funnel metric visualization in dashboard/src/components/charts/FunnelChart.tsx

**Checkpoint**: Custom metric definitions (ratio, funnel) compute correctly and display in results.

---

## Phase 23: User Story 21 — PM Views Experiment Timeline (Priority: P5)

**Goal**: Gantt-style timeline view showing all experiments that ran on a feature or page, with durations, statuses, and outcomes.

**Independent Test**: Create multiple experiments, conclude some, verify timeline renders correctly with overlapping periods highlighted.

### Tests for User Story 21 ⚠️

- [X] T296 [P] [US21] Write Vitest component test for ExperimentTimeline (Gantt chart rendering with overlaps) in dashboard/tests/unit/ExperimentTimeline.test.tsx

### Implementation for User Story 21

- [X] T297 [US21] Implement experiment timeline query (experiments by feature tag, ordered by start date) in apps/experiment_hub/lib/experiment_hub/analytics.ex
- [X] T298 [US21] Implement ExperimentTimeline page with Gantt-style chart using Recharts in dashboard/src/pages/ExperimentTimelinePage.tsx
- [X] T299 [US21] Implement overlap detection and visual highlighting in timeline component in dashboard/src/components/charts/TimelineChart.tsx

**Checkpoint**: Experiment timeline provides historical context for features. All P5 analytics stories complete.

---

## Phase 24: Polish & Cross-Cutting Concerns

**Purpose**: Security hardening, GDPR compliance, performance validation, data retention, and quickstart scenario execution.

### GDPR Compliance

- [X] T300 [P] Implement GDPR user data anonymization endpoint (FR-072): anonymize all data for a specific user_id across all experiments and events. Use deterministic pseudonymization via `SHA-256(tenant_id || user_id || per-tenant-salt)`. For >100K records, execute as background Oban job in apps/experiment_hub/lib/experiment_hub/gdpr.ex
- [X] T339 [P] Create anonymization_requests Ecto schema and migration per data-model.md for tracking GDPR anonymization progress in apps/experiment_hub/lib/experiment_hub/gdpr/anonymization_request.ex and apps/experiment_hub/priv/repo/migrations/
- [X] T340 Implement GdprController with POST /api/v1/gdpr/anonymize and GET /api/v1/gdpr/anonymization-requests/:id endpoints per management-api.md contract in apps/experiment_hub_web/lib/experiment_hub_web/controllers/gdpr_controller.ex
- [X] T341 [P] Write contract test for POST /api/v1/gdpr/anonymize (immediate and background processing paths) and GET /api/v1/gdpr/anonymization-requests/:id in apps/experiment_hub_web/test/experiment_hub_web/controllers/gdpr_controller_test.exs
- [X] T301 [P] Implement GDPR tenant deletion endpoint (FR-073): cascade delete all tenant data on offboarding with 72-hour soft-delete grace period. Set `deletion_scheduled_at` on tenant record, disable API keys immediately. Implement Oban worker for permanent deletion after grace period in apps/experiment_hub/lib/experiment_hub/gdpr.ex
- [X] T342 Implement tenant deletion cancellation endpoint: DELETE /api/v1/tenants/:id/cancel to abort pending deletions during grace period in apps/experiment_hub_web/lib/experiment_hub_web/controllers/tenant_controller.ex
- [X] T302 [P] Write integration test for GDPR anonymization covering experiments, events, assignments, and audit logs in apps/experiment_hub/test/experiment_hub/gdpr_test.exs

### Data Retention & Partitioning

- [X] T303 [P] Implement Oban worker for automatic monthly partition creation (experiment_events_raw, experiment_results_daily, audit_logs) in apps/experiment_hub/lib/experiment_hub/workers/partition_manager_worker.ex
- [X] T304 [P] Implement Oban worker for 90-day partition retention cleanup (FR-051): drop experiment_events_raw partitions older than 90 days in apps/experiment_hub/lib/experiment_hub/workers/retention_worker.ex

### Performance & Load Testing

- [X] T305 [P] Create k6 load test script for assignment endpoint: target 10K rps, validate <5ms p99 (NFR-001) in k6/assignment_load.js
- [X] T306 [P] Create k6 load test script for event ingestion: target 50K events/sec sustained (NFR-002) in k6/event_ingestion_load.js
- [X] T307 [P] Create k6 load test script for dashboard result queries: validate <2sec on 10M+ events (NFR-003) in k6/dashboard_load.js

### Cross-Platform Assignment

- [X] T308 [P] Implement WASM build target for assignment_core (browser SDK use): wasm-bindgen bindings in assignment_core/src/wasm.rs

### Event Replay & Schema Versioning (Constitution Art.V)

> **Note**: Schema versioning (T332/T333) is placed in Phase 24 for pragmatic reasons � v1 starts with schema_version=1 on all topics. However, the `schema_version` field MUST be present in all Kafka messages from the start (included in data-model.md Kafka schemas). T332/T333 add the backward-compatible validation logic needed when schema_version=2 is introduced.

- [X] T332 [P] Add `schema_version` field to all Kafka topic message schemas (assignment_events, experiment_events_raw, metric_events, experiment_lifecycle); implement backward-compatible schema validation in event producer and consumer modules in apps/experiment_hub/lib/experiment_hub/events/schema_versioning.ex
- [X] T333 [P] Write integration test: produce events with schema v1, upgrade to v2, verify consumer handles both versions without data loss in apps/experiment_hub/test/experiment_hub/events/schema_versioning_test.exs
- [X] T334 Implement Kafka event replay Mix task: re-consume events from a topic/partition range for a given experiment_id and re-run aggregation to verify result reproducibility (Constitution Art.V �3) in apps/experiment_hub/lib/mix/tasks/replay_events.ex
- [X] T335 Write integration test for event replay: produce known events, run replay task, assert aggregated results match original analysis output in apps/experiment_hub/test/experiment_hub/events/replay_test.exs

### Distributed Tracing (Constitution Art.IX)

- [X] T336 [P] Implement W3C Trace Context middleware in FastAPI statistical engine: extract traceparent/tracestate from inbound requests, inject into logs and response headers in statistical_engine/src/api/middleware/tracing.py
- [X] T337 [P] Write integration test: verify traceparent header round-trips from Elixir analysis_worker ? FastAPI statistical engine ? response, with trace_id present in statistical engine logs in apps/experiment_hub/test/experiment_hub/tracing/cross_service_test.exs

### Cross-Service Contract Tests (Constitution Art.III)

- [X] T338 Write ExUnit contract test: validate Elixir HTTP client request format and response parsing against statistical-api.md contract schema (request body shape, response status codes, error format) in apps/experiment_hub/test/experiment_hub/contracts/statistical_api_contract_test.exs

### End-to-End Validation

- [X] T310 Write Playwright E2E test for full experiment lifecycle (quickstart scenario 1): create → launch → assign → events → results → conclude in dashboard/tests/e2e/experiment-lifecycle.spec.ts
- [X] T311 Write Playwright E2E test for multi-tenant isolation (quickstart scenario 4): verify tenant A never sees tenant B data in dashboard/tests/e2e/tenant-isolation.spec.ts
- [X] T312 Execute all 5 quickstart.md validation scenarios against running Docker Compose environment and document results

### NFR Validation

- [X] T326 Write capacity test for NFR-006: create and run 100 concurrent experiments with interleaved assignments and event ingestion, verify system stability in k6/concurrent_experiments_load.js
- [X] T327 Write stat computation benchmark for NFR-008: run analysis on experiment with 1M events, assert computation completes within 30 seconds in statistical_engine/tests/test_performance.py
- [X] T328 Write multi-tenant capacity test for NFR-009: provision 5 tenants each with 20 active experiments, verify isolation and performance under concurrent load in k6/multi_tenant_capacity.js
- [X] T329 Write availability monitoring integration test for NFR-004: verify health check endpoints, graceful degradation under dependency failure, and recovery behavior in apps/experiment_hub_web/test/experiment_hub_web/availability_test.exs

### Security Hardening

- [X] T313 Security audit: verify all RLS policies are active on every tenant-scoped table, test with SQL injection attempts
- [X] T314 Security audit: verify API key hashing (SHA-256), no raw keys stored, input validation on all endpoints, rate limiting functional
- [X] T315 [P] Implement data access logging middleware for GDPR compliance auditing (FR-074): log all read/write access to PII-containing tables with actor, resource, timestamp in apps/experiment_hub_web/lib/experiment_hub_web/plugs/data_access_logger.ex
- [X] T325 [P] Write integration test for data access logging: verify all experiment/event/user data access produces audit entries in apps/experiment_hub/test/experiment_hub/audit/data_access_logging_test.exs

### Observability (Constitution Article IX)

- [X] T343 [P] Configure PromEx HTTP endpoint to expose Prometheus-compatible metrics at GET /metrics on the Phoenix application (Constitution Article IX �3) in apps/experiment_hub_web/lib/experiment_hub_web/endpoint.ex
- [X] T344 [P] Configure Prometheus-compatible metrics endpoint at GET /metrics on the FastAPI statistical engine (Constitution Article IX �3) in statistical_engine/src/api/main.py

### Event Buffer for Kafka Unavailability

- [X] T345 Implement disk-backed event buffer for Kafka unavailability: when Kafka is unreachable, buffer events to a local disk-backed queue (configurable max size, default 1GB) with retry and exponential backoff. Events are replayed in order when Kafka recovers. When buffer is full, return 503 with Retry-After header (spec edge case + T107) in apps/event_collector/lib/event_collector/buffer/disk_buffer.ex
- [X] T346 [P] Write integration test for disk-backed buffer: simulate Kafka unavailability, verify events are buffered, then verify replay on recovery in apps/event_collector/test/event_collector/buffer/disk_buffer_test.exs

### SDK Documentation

- [X] T347 Create SDK integration quickstart guide for Elixir/Phoenix applications (SC-005: 30-minute integration target) in docs/sdk/elixir-quickstart.md
- [X] T348 Create SDK integration quickstart guide for JavaScript/TypeScript applications (browser WASM + event tracking) in docs/sdk/javascript-quickstart.md
- [X] T349 Create API reference documentation covering all public endpoints (Assignment API, Event API, Feature Flags) in docs/api-reference.md

### Authentication Contract

- [X] T350 [P] Write contract test for POST /api/v1/auth/login and POST /api/v1/auth/refresh endpoints per management-api.md in apps/experiment_hub_web/test/experiment_hub_web/controllers/auth_controller_test.exs
- [X] T351 Implement AuthController with POST /api/v1/auth/login (JWT generation) and POST /api/v1/auth/refresh endpoints per management-api.md contract in apps/experiment_hub_web/lib/experiment_hub_web/controllers/auth_controller.ex

**Checkpoint**: Production-ready � load tests passing, GDPR-compliant, security hardened, quickstart validated, observability complete, all cross-cutting concerns addressed.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1: Setup ──────────────────────── No dependencies
    │
    ▼
Phase 2: Foundational ──────────────── Depends on Phase 1 (BLOCKS all user stories)
    │
    ├──► Phase 3: US1 (Create Experiment) ─── Must be first user story
    │        │
    │        ├──► Phase 4: US2 (Assignment) ──── Depends on US1 (needs experiments)
    │        │
    │        ├──► Phase 5: US3 (Events) ────────── Depends on US1 (needs experiments)
    │        │        │
    │        │        ▼
    │        │    Phase 6: US4 (Stats) ─────────── Depends on US3 (needs events)
    │        │
    │        └──► Phase 7: US5 (Dashboard) ────── Depends on US1 (can start early)
    │                 │
    │                 ▼
    │             Phase 8: US6 (Conclude) ──────── Depends on US1 + US5
    │
    ├──► Phase 9: US7 (Multivariate) ──────── Depends on US1 + US2 + US4
    ├──► Phase 10: US8 (Targeting) ────────── Depends on US2
    ├──► Phase 11: US9 (Guardrails) ───────── Depends on US4
    ├──► Phase 12: US10 (Scheduling) ──────── Depends on US1
    ├──► Phase 13: US11 (Bayesian) ────────── Depends on US4
    │
    ├──► Phase 14: US12 (Exclusion Groups) ── Depends on US2
    ├──► Phase 15: US13 (Audit Trail UI) ──── Depends on US6 (audit context)
    ├──► Phase 16: US14 (Tenant Mgmt) ─────── Depends on Foundational
    ├──► Phase 17: US15 (Export) ───────────── Depends on US4
    │
    ├──► Phase 18: US16 (Feature Flags) ───── Depends on US2
    ├──► Phase 19: US17 (Rollouts) ────────── Depends on US16
    ├──► Phase 20: US18 (Flag Targeting) ──── Depends on US8 + US16
    │
    ├──► Phase 21: US19 (Platform Dashboard) ─ Depends on US1 + US4
    ├──► Phase 22: US20 (Custom Metrics) ───── Depends on US4
    └──► Phase 23: US21 (Timeline) ────────── Depends on US1
         │
         ▼
    Phase 24: Polish ──────────────────── Depends on all desired user stories
```

### User Story Dependencies

| User Story | Depends On | Can Parallel With |
|-----------|------------|-------------------|
| US1 (Create Experiment) | Foundational only | — (must be first) |
| US2 (Assignment) | US1 | US3, US5 |
| US3 (Event Collection) | US1 | US2, US5 |
| US4 (Statistical Analysis) | US3 | US5 (partially) |
| US5 (Dashboard) | US1 | US2, US3 |
| US6 (Conclude) | US1, US5 | — |
| US7 (Multivariate) | US1, US2, US4 | US8, US10 |
| US8 (Targeting) | US2 | US7, US9, US10 |
| US9 (Guardrails) | US4 | US8, US10 |
| US10 (Scheduling) | US1 | US7, US8, US9 |
| US11 (Bayesian) | US4 | US7-US10 |
| US12 (Exclusion Groups) | US2 | US13-US15 |
| US13 (Audit Trail UI) | US6 | US12, US14, US15 |
| US14 (Tenant Mgmt) | Foundational | US12, US13, US15 |
| US15 (Export) | US4 | US12-US14 |
| US16 (Feature Flags) | US2 | US12-US15 |
| US17 (Rollouts) | US16 | US18 |
| US18 (Flag Targeting) | US8, US16 | — |
| US19 (Platform Dashboard) | US1, US4 | US20, US21 |
| US20 (Custom Metrics) | US4 | US19, US21 |
| US21 (Timeline) | US1 | US19, US20 |

### Within Each User Story

1. Tests MUST be written first and FAIL (Article III: TDD)
2. Models/schemas before contexts/services
3. Contexts/services before controllers
4. Controllers before dashboard components
5. Story complete before marking checkpoint

### Parallel Execution Examples

**Maximum parallelism after Foundational phase:**

```
Developer 1: US1 (Create Experiment)
                 ↓
              US2 (Assignment) ──────────────────────► US8 (Targeting) ──► US18 (Flag Targeting)
                                                        │
Developer 2: US1 ──► US3 (Events) ──► US4 (Stats) ──► US9 (Guardrails)
                                          │
Developer 3: US1 ──► US5 (Dashboard) ──► US6 (Conclude) ──► US15 (Export)
                                                              │
Developer 4: (after Foundational) ──► US14 (Tenant Mgmt) ──► US16 (Feature Flags) ──► US17 (Rollouts)
```

---

## Implementation Strategy

### MVP Scope (User Stories 1-6, Priority P1)

- **Phases 1-8** deliver the complete experimentation loop
- Total MVP tasks: **174 tasks** (T001-T174)
- MVP includes: create experiment → assign variants → collect events → analyze stats → view dashboard → conclude
- MVP is independently deployable and testable

### Incremental Delivery Order

1. **MVP**: US1-US6 (core loop) — Phases 1-8
2. **Advanced Stats**: US7 + US11 (multivariate + Bayesian) — Phases 9, 13
3. **Targeting**: US8 + US10 (targeting rules + scheduling) — Phases 10, 12
4. **Safety**: US9 (guardrails) — Phase 11
5. **Governance**: US12-US14 (exclusion groups, audit UI, tenant mgmt) — Phases 14-16
6. **Export**: US15 — Phase 17
7. **Feature Flags**: US16-US18 — Phases 18-20
8. **Analytics**: US19-US21 — Phases 21-23
9. **Polish**: Cross-cutting — Phase 24

