# Mega-Prompt: Build an A/B Testing & Experimentation Platform

## Context & Role

You are a senior full-stack architect and product engineer tasked with building **ExperimentHub** — a self-hosted, production-grade A/B Testing & Experimentation Platform. You will follow **Spec-Driven Development (SDD)** methodology using the GitHub Spec Kit workflow. This means specifications are the source of truth, code serves specifications, and every implementation decision traces back to a concrete requirement.

You are working inside a monorepo. The project will be built across **6 SDD phases**, each producing specific artifacts before moving to the next. Do NOT skip phases. Do NOT write implementation code until Phase 5.

---

## Phase 0: Constitution — Governing Principles

**Command**: `/speckit.constitution`

Create `specs/experimenthub/constitution.md` establishing the immutable architectural principles for ExperimentHub. The constitution MUST include the following articles:

### Required Articles

**Article I: Service-Oriented Modularity**
- The platform is composed of discrete services: Assignment Engine, Event Collector, Statistical Engine, Management API, Dashboard UI, and Reporting Pipeline.
- Each service has a clear boundary, owns its data, and communicates via defined contracts (REST APIs, Kafka topics, or direct function calls within a monorepo).
- No service may directly access another service's database tables.

**Article II: Statistical Rigor as a First-Class Citizen**
- All experiment conclusions MUST be backed by valid statistical methods (frequentist or Bayesian).
- The platform MUST NOT declare a winner without reaching configured statistical significance thresholds.
- Sample size calculations, power analysis, and multiple comparison corrections are mandatory, not optional features.
- Every statistical computation must be auditable — inputs, methodology, and outputs logged.

**Article III: Test-First Development**
- TDD is non-negotiable. All implementation MUST follow Red → Green → Refactor.
- Statistical functions require property-based testing (hypothesis testing with known distributions).
- Integration tests must use real PostgreSQL (via Docker), not mocks.
- Contract tests between services are mandatory before implementation.

**Article IV: Deterministic Assignment**
- User-to-variant assignment MUST be deterministic and reproducible given the same (user_id, experiment_id) pair.
- Assignment must be consistent across requests (no flip-flopping).
- The hashing algorithm must produce uniform distribution verifiable by chi-squared tests.
- Assignment logic must be extractable as a standalone library usable by any service in any language.

**Article V: Event Sourcing & Auditability**
- All experiment lifecycle events (created, started, paused, stopped, concluded) are immutable and append-only.
- All assignment events and metric events flow through Kafka and are persisted.
- Any experiment result must be reproducible by replaying events from Kafka.
- Audit trail for who changed what, when, and why.

**Article VI: Performance & Scalability**
- Assignment endpoint: < 5ms p99 latency at 10,000 requests/second.
- Event ingestion: handle 50,000 events/second sustained throughput via Kafka.
- Dashboard queries: < 2 seconds for experiment results aggregation on 10M+ events.
- Statistical computations: < 30 seconds for full Bayesian analysis on experiments with 1M+ observations.

**Article VII: Simplicity & YAGNI**
- Start with the simplest implementation that satisfies requirements.
- No speculative features ("might need later").
- Maximum 5 services for v1. Additional services require documented justification.
- Use framework features directly — no unnecessary abstraction layers.

**Article VIII: Multi-Tenancy from Day One**
- All data is tenant-scoped. No query may return cross-tenant data.
- Tenant isolation at the database level (schema-per-tenant or row-level security).
- API authentication is per-tenant with API keys and optional OAuth.

**Article IX: Observability**
- Structured logging (JSON) on every service.
- Health check endpoints on every service.
- Prometheus-compatible metrics exposed by every service.
- Distributed tracing headers propagated across service boundaries.

### Governance
- Constitution supersedes all other documents and development practices.
- Amendments require: written rationale, impact analysis, and explicit approval.
- All PRs must include a constitution compliance checklist.

---

## Phase 1: Specification — What & Why (Not How)

**Command**: `/speckit.specify`

Create `specs/experimenthub/spec.md` — a comprehensive Product Requirements Document. Focus exclusively on WHAT users need and WHY. Do NOT include technology choices, API designs, or code structure.

### Product Vision

ExperimentHub is a self-hosted experimentation platform that enables product teams to run A/B tests, multivariate tests, and feature rollouts with statistical rigor. It replaces expensive SaaS tools (LaunchDarkly, Optimizely, Statsig) for organizations that need data sovereignty, customization, and cost control.

### Target Personas

1. **Product Manager (Primary)** — Creates experiments, defines hypotheses, reviews results, makes ship/no-ship decisions.
2. **Data Analyst** — Configures metrics, reviews statistical methodology, validates results, creates custom reports.
3. **Software Engineer** — Integrates SDK into application code, checks experiment assignments, logs events.
4. **Engineering Manager** — Reviews experiment velocity, monitors system health, manages team permissions.
5. **Platform Admin** — Manages tenants, API keys, system configuration, monitors infrastructure.

### User Stories — Prioritized & Independently Testable

Write detailed user stories for each of the following, with Given/When/Then acceptance scenarios:

**P1 — Core Experimentation Loop (MVP)**
- US1: PM creates an A/B experiment with hypothesis, variants, traffic allocation, and primary metric.
- US2: Engineer integrates SDK and gets deterministic variant assignments for users.
- US3: Event collector receives and persists conversion/metric events from the application.
- US4: Platform computes experiment results with statistical significance in real-time.
- US5: PM views experiment dashboard showing variant performance, confidence intervals, and recommendation.
- US6: PM stops the experiment and records the decision (ship variant B / revert to control).

**P2 — Advanced Experimentation**
- US7: PM creates multivariate test (A/B/C/D) with custom traffic splits.
- US8: PM configures experiment targeting rules (segment by country, device, user property).
- US9: Analyst configures guardrail metrics that auto-pause experiments if degraded.
- US10: PM schedules experiment start/end dates with automatic lifecycle management.
- US11: Analyst views experiment results with Bayesian probability-to-be-best alongside frequentist p-values.

**P3 — Collaboration & Governance**
- US12: PM adds experiment to a mutual exclusion group (users in experiment A cannot be in experiment B).
- US13: Manager reviews experiment history with full audit trail of changes.
- US14: Admin creates tenants, manages API keys, assigns role-based permissions (viewer/editor/admin).
- US15: Analyst exports experiment results to Power BI / Excel (CSV, JSON, Excel formats).

**P4 — Feature Flags & Rollouts**
- US16: Engineer uses the same SDK for simple feature flags (on/off) without full experiment setup.
- US17: PM creates a percentage-based rollout (ship to 5% → 25% → 50% → 100%).
- US18: Engineer gets feature flag evaluation with targeting rules (user properties, segments).

**P5 — Analytics & Reporting**
- US19: Analyst views platform-wide dashboard: active experiments, concluded this month, average experiment duration, statistical power distribution.
- US20: Analyst creates custom metric definitions (composite metrics, ratio metrics, funnel metrics).
- US21: PM views experiment timeline showing all experiments that affected a given feature/page.

### Edge Cases (must be addressed in spec)
- What happens when an experiment is modified while running (e.g., traffic allocation changed)?
- What happens when the assignment service is down — does the application fail open or closed?
- How are bot/crawler events filtered from experiment results?
- What happens when an experiment reaches significance early (peeking problem)?
- How are experiments handled for anonymous users who later authenticate (identity stitching)?
- What if two experiments modify the same UI element simultaneously (interaction effects)?

### Functional Requirements (FR-001 through FR-050+)
Write at least 50 functional requirements covering:
- Experiment lifecycle management (CRUD, state machine: draft → running → paused → concluded)
- Variant assignment algorithm (deterministic hashing, uniform distribution)
- Event ingestion (batch and real-time, schema validation, deduplication)
- Statistical engine (frequentist: z-test, chi-squared, t-test; Bayesian: Thompson sampling, Beta-Binomial)
- Targeting and segmentation (user properties, custom attributes, percentage-based)
- Mutual exclusion groups and experiment layers
- Multi-tenancy (tenant isolation, API key management, RBAC)
- SDK contract (assignment endpoint, event tracking endpoint, feature flag evaluation)
- Data retention and archival policies
- Rate limiting and abuse prevention

### Non-Functional Requirements
- NFR-001: Assignment latency < 5ms p99
- NFR-002: Event ingestion throughput > 50,000 events/sec
- NFR-003: Dashboard load time < 2 seconds
- NFR-004: System availability > 99.9% (assignment endpoint)
- NFR-005: Data retention: raw events 90 days, aggregated results permanent
- NFR-006: Support 100+ concurrent experiments per tenant
- NFR-007: GDPR-compliant data handling (anonymization, deletion)

### Key Entities (no implementation details)
- Experiment, Variant, ExperimentGroup (mutual exclusion), Metric, MetricDefinition
- Assignment, Event, ExperimentResult, StatisticalAnalysis
- Tenant, User, APIKey, Permission, AuditLog
- TargetingRule, Segment, FeatureFlag

### Success Criteria
- SC-001: An experiment can be created, launched, and concluded within 5 minutes via the UI.
- SC-002: Assignment SDK adds < 2ms overhead to application response time.
- SC-003: Statistical engine matches results from R/scipy within 0.1% margin on reference datasets.
- SC-004: Platform handles 10 concurrent experiments with 1M users each without degradation.
- SC-005: New engineer can integrate SDK and run first experiment within 30 minutes using docs.

---

## Phase 2: Implementation Plan — Technical Architecture

**Command**: `/speckit.plan`

Create `specs/experimenthub/plan.md` and supporting documents. NOW you define the how.

### Technical Context (Mandatory)

```
Language/Versions:
  - Backend API/Real-time: Elixir 1.16+ / Erlang/OTP 26+ / Phoenix 1.7+
  - Statistical Engine: Python 3.12+
  - Assignment SDK Library: Rust (compiled to WASM for browser, native for server-side)
  - Dashboard Frontend: React.js 18+ with TypeScript
  - Data Pipeline Workers: Python 3.12+

Primary Dependencies:
  - Elixir/Phoenix: Phoenix LiveView, Ecto, Broadway (Kafka consumer), Jason
  - Python: FastAPI (statistical engine API), scipy, numpy, pymc (Bayesian), pandas, kafka-python
  - Rust: sha2 (hashing), wasm-bindgen (WASM compilation), serde
  - React: React Router, TanStack Query, Recharts, shadcn/ui
  - Infrastructure: Apache Kafka 3.6+, PostgreSQL 16+, Redis 7+ (caching)

Storage:
  - PostgreSQL 16: Primary datastore (experiments, configs, results, tenants, audit logs)
  - Apache Kafka: Event streaming (assignments, metric events, lifecycle events)
  - Redis 7: Assignment cache, rate limiting, session cache

Testing:
  - Elixir: ExUnit, Mox, Wallaby (integration)
  - Python: pytest, hypothesis (property-based), pytest-asyncio
  - Rust: cargo test, proptest (property-based)
  - React: Vitest, React Testing Library, Playwright (E2E)
  - Integration: Docker Compose test environment with real Kafka + PostgreSQL

Deployment:
  - Docker Compose for local development and single-server deployment
  - Docker images published to container registry
  - AWS deployment: ECS (Fargate) or EC2 + RDS (PostgreSQL) + MSK (Kafka)
  - GitHub Actions CI/CD pipeline

Performance Goals:
  - Assignment: < 5ms p99 at 10K rps
  - Event ingestion: 50K events/sec sustained
  - Statistical computation: < 30 sec for 1M observations (Bayesian)
  - Dashboard: < 2 sec page load

Scale:
  - v1 target: 100 concurrent experiments, 10M events/day, 5 tenants
  - Design for 10x growth without architectural changes
```

### Architecture — Service Breakdown

Document these services with their responsibilities, tech stack, and contracts:

**1. Management API (Elixir/Phoenix)**
- Experiment CRUD, lifecycle state machine, tenant management, RBAC
- REST API + Phoenix LiveView admin panels
- Ecto schemas with PostgreSQL
- Publishes experiment lifecycle events to Kafka
- Serves as the central orchestrator

**2. Assignment Engine (Rust → exposed via Elixir NIF + standalone HTTP)**
- Deterministic MurmurHash3/SHA-256 based user→variant assignment
- Published as: Rust library, Elixir NIF, WASM package (browser SDK), HTTP microservice
- Caches active experiment configs from Redis
- Must be extractable as a standalone library
- < 5ms p99 latency

**3. Event Collector (Elixir/Broadway)**
- High-throughput HTTP endpoint for receiving events (batch + single)
- Schema validation, deduplication (idempotency keys)
- Publishes to Kafka topics partitioned by experiment_id
- Handles backpressure gracefully via Broadway

**4. Statistical Engine (Python/FastAPI)**
- Consumes aggregated data from PostgreSQL (not raw Kafka events)
- Frequentist tests: z-test for proportions, Welch's t-test for continuous metrics, chi-squared for categorical
- Bayesian analysis: Beta-Binomial for conversion rates, Normal-Normal for continuous metrics
- Sequential analysis: alpha-spending functions to handle peeking
- Exposes REST API consumed by the Management API/Dashboard
- Computation results cached in PostgreSQL

**5. Data Pipeline (Python workers consuming Kafka)**
- Consumes raw events from Kafka
- Aggregates into per-experiment, per-variant, per-metric rollup tables in PostgreSQL
- Handles late-arriving events with watermarking
- Runs on configurable schedule (near-real-time: every 60 seconds)

**6. Dashboard (React.js)**
- Experiment list, creation wizard, detail view with live results
- Interactive charts: conversion rate over time, confidence interval visualization, cumulative lift
- Feature flag management UI
- Tenant admin panel (API keys, users, permissions)
- Export to CSV/Excel/JSON
- Connects to Management API via REST, receives live updates via WebSocket (Phoenix Channels)

### Supporting Documents to Generate

Create these additional documents in `specs/experimenthub/`:

**`data-model.md`** — Complete entity-relationship model with:
- All tables, columns, types, constraints, indexes
- PostgreSQL-specific: row-level security policies for multi-tenancy, partitioning strategy for events
- Kafka topic schemas (Avro or JSON Schema)
- Redis key patterns and TTL policies

**`contracts/assignment-api.md`** — OpenAPI 3.1 spec for assignment endpoint:
- `POST /v1/assign` — Get variant for user+experiment
- `POST /v1/assign/batch` — Batch assignment for multiple experiments
- `GET /v1/flags/{flag_key}` — Feature flag evaluation

**`contracts/event-api.md`** — OpenAPI 3.1 spec for event collection:
- `POST /v1/events` — Single event
- `POST /v1/events/batch` — Batch events
- Event schema: `{tenant_id, experiment_id, user_id, event_type, event_name, value, properties, timestamp, idempotency_key}`

**`contracts/management-api.md`** — OpenAPI 3.1 spec for CRUD operations:
- Experiments: CRUD, start, pause, stop, conclude
- Metrics: CRUD, attach to experiment
- Targeting rules: CRUD
- Tenants: CRUD (admin only)
- API Keys: generate, revoke, list
- Results: get experiment results, export

**`contracts/statistical-api.md`** — OpenAPI 3.1 spec for statistical engine:
- `POST /v1/analyze/{experiment_id}` — Run full analysis
- `GET /v1/analyze/{experiment_id}/results` — Get cached results
- `POST /v1/power` — Sample size / power calculation
- Response schema: `{frequentist: {p_value, confidence_interval, effect_size}, bayesian: {probability_to_be_best, credible_interval, expected_loss}}`

**`research.md`** — Technical research documenting:
- Hash algorithm comparison (MurmurHash3 vs SHA-256 vs xxHash) for assignment uniformity
- Bayesian vs Frequentist tradeoffs for the statistical engine
- Kafka partitioning strategy for event ordering guarantees
- PostgreSQL partitioning strategy for high-volume event tables
- Elixir Broadway vs GenStage vs manual Kafka consumer tradeoffs
- Rust NIF safety considerations in BEAM VM
- WASM bundle size optimization for browser SDK

**`quickstart.md`** — Key validation scenarios:
1. Create experiment → assign user → log event → see result (happy path end-to-end)
2. Verify assignment determinism (same user+experiment always returns same variant)
3. Verify statistical significance computation matches scipy reference
4. Verify multi-tenant isolation (tenant A cannot see tenant B experiments)
5. Load test: 10K assignment requests/second with < 5ms p99

---

## Phase 3: Task Breakdown — Executable Work Items

**Command**: `/speckit.tasks`

Create `specs/experimenthub/tasks.md` organizing work into phases and user stories with parallelization markers.

### Required Task Structure

**Phase 1: Project Setup & Infrastructure (12-15 tasks)**
- Initialize monorepo structure (Elixir umbrella app, Python packages, Rust workspace, React app)
- Docker Compose: PostgreSQL 16, Kafka (KRaft mode), Redis 7, Zookeeper-less
- Database migrations framework (Ecto migrations)
- Kafka topic creation scripts
- CI/CD pipeline (GitHub Actions): lint, test, build, Docker image push
- Environment configuration (dev, test, staging, prod)
- Shared protobuf/JSON schema definitions for cross-service contracts

**Phase 2: Foundational Infrastructure (18-22 tasks)**
- PostgreSQL schema: tenants, users, api_keys, permissions tables + RLS policies
- Authentication middleware (API key validation, JWT for dashboard)
- Tenant context propagation (all queries scoped to tenant)
- Kafka producer/consumer base modules (Elixir Broadway setup)
- Redis connection pool and cache helpers
- Structured logging setup (JSON, correlation IDs)
- Health check endpoints for all services
- Error handling and graceful degradation patterns

**Phase 3: US1-US3 — Core Assignment & Events (MVP Part 1) (20-25 tasks)**
- Rust assignment library: MurmurHash3 implementation, uniform distribution, property-based tests
- Elixir NIF wrapper for Rust assignment library
- Assignment HTTP endpoint (Elixir/Phoenix)
- Assignment caching layer (Redis)
- Experiment CRUD API (Elixir/Phoenix + Ecto)
- Experiment state machine (draft → running → paused → concluded)
- Event collector HTTP endpoint (Elixir/Broadway)
- Event schema validation and deduplication
- Kafka producer for assignment events and metric events
- Contract tests for all APIs

**Phase 4: US4-US6 — Statistical Engine & Dashboard (MVP Part 2) (25-30 tasks)**
- Python statistical engine: z-test, Welch's t-test implementations with tests against scipy
- Bayesian engine: Beta-Binomial conjugate analysis
- Sequential analysis: O'Brien-Fleming alpha spending
- Statistical API (FastAPI) with result caching
- Data pipeline: Kafka consumer → PostgreSQL aggregation tables
- React dashboard: experiment list, creation wizard
- React dashboard: experiment detail view with results visualization
- React dashboard: confidence interval charts (Recharts)
- Phoenix Channels integration for live result updates
- End-to-end test: full experiment lifecycle

**Phase 5: US7-US11 — Advanced Experimentation (20-25 tasks)**
- Multivariate experiment support (A/B/C/D/N variants)
- Targeting rules engine (user properties, segments, percentage)
- Guardrail metrics with automatic pause triggers
- Experiment scheduling (start/end dates, cron-based lifecycle)
- Bayesian probability-to-be-best visualization
- Multiple comparison correction (Bonferroni, Holm-Šidák)

**Phase 6: US12-US15 — Collaboration & Governance (15-18 tasks)**
- Mutual exclusion groups (experiment layers)
- Audit log for all experiment changes
- RBAC: viewer, editor, admin roles per tenant
- Export: CSV, JSON, Excel generation
- Power BI integration endpoint (OData or REST)

**Phase 7: US16-US18 — Feature Flags (12-15 tasks)**
- Feature flag model (simplified experiment: on/off toggle)
- Percentage-based rollout with ramp-up
- Targeting rules for feature flags
- SDK: `isEnabled(flagKey, userId, attributes)` interface

**Phase 8: US19-US21 — Analytics & Platform Dashboard (10-12 tasks)**
- Platform-wide analytics dashboard
- Custom metric definitions (composite, ratio, funnel)
- Experiment timeline view (Gantt-style)

**Phase 9: Polish & Hardening (15-20 tasks)**
- Performance optimization: query tuning, index optimization, connection pooling
- Security hardening: rate limiting, input sanitization, CORS, CSP headers
- Documentation: API docs (Swagger UI), SDK integration guide, architecture decision records
- Monitoring: Prometheus metrics, Grafana dashboards
- Load testing: k6 scripts for assignment endpoint, event ingestion, dashboard
- GDPR: data anonymization endpoints, tenant data deletion

### Task Format

Every task must follow this format:
```
- [ ] T{NNN} [P?] [US{N}] {Description} — {exact file path}
```
- `[P]` = can run in parallel with other [P] tasks in same phase
- `[US{N}]` = which user story this implements
- Include exact file paths for every task

### Dependency Rules
- Phase 1 (Setup) → Phase 2 (Foundation) → Phase 3+ (User Stories)
- Within Phase 3+, user story phases can run in parallel if staffed
- Within each user story: tests → models → services → endpoints → UI
- Cross-service contracts must be defined before implementation

---

## Phase 4: Pre-Implementation Analysis

**Command**: `/speckit.analyze`

Before implementation, perform cross-artifact consistency analysis:

1. **Spec ↔ Plan traceability**: Every FR in spec.md maps to a component in plan.md
2. **Plan ↔ Tasks traceability**: Every component in plan.md has tasks in tasks.md
3. **Contract consistency**: API contracts in `contracts/` match the data model in `data-model.md`
4. **User story coverage**: Every user story has acceptance scenarios AND corresponding tasks
5. **Dependency validation**: No circular dependencies in task execution order
6. **Constitution compliance**: Plan passes all gates (simplicity, anti-abstraction, test-first, integration-first)
7. **Performance feasibility**: Stated performance goals are achievable with chosen technology stack

Output a consistency report identifying gaps, conflicts, and recommendations.

---

## Phase 5: Implementation

**Command**: `/speckit.implement`

Execute tasks in order defined by tasks.md. For each task:

1. Write failing tests FIRST (Red phase)
2. Implement minimum code to pass tests (Green phase)
3. Refactor for clarity (Refactor phase)
4. Verify constitution compliance
5. Update audit checkpoint

### Implementation Guidelines

**Elixir/Phoenix (Management API + Event Collector)**
```
Use Elixir umbrella app structure:
  apps/
    experiment_hub/        # Core domain logic (Ecto schemas, business logic)
    experiment_hub_web/    # Phoenix web layer (controllers, channels, LiveView)
    event_collector/       # Broadway-based high-throughput event ingestion
    assignment_engine/     # Elixir NIF wrapper around Rust assignment library

Key libraries:
  - Broadway + BroadwayKafka for Kafka consumption
  - Ecto for PostgreSQL with multi-tenancy via schema prefixes or RLS
  - Phoenix Channels for live dashboard updates
  - Jason for JSON encoding/decoding
  - NimbleOptions for configuration validation
  - Oban for background job processing (scheduled experiments, cleanup)
```

**Python (Statistical Engine + Data Pipeline)**
```
Use Python package structure:
  statistical_engine/
    api/                   # FastAPI application
    core/
      frequentist.py       # z-test, t-test, chi-squared
      bayesian.py          # Beta-Binomial, Normal-Normal conjugate
      sequential.py        # Alpha spending functions, early stopping
      power.py             # Sample size calculations
    models/                # Pydantic models
    tests/
      test_frequentist.py  # Property-based tests against scipy
      test_bayesian.py     # Tests against PyMC reference

  data_pipeline/
    consumers/             # Kafka consumers
    aggregators/           # Rollup computation
    transforms/            # Data cleaning, bot filtering
```

**Rust (Assignment Library)**
```
  assignment-engine/
    src/
      lib.rs              # Core hashing + assignment logic
      hash.rs             # MurmurHash3 implementation
      distribution.rs     # Uniform distribution + traffic allocation
      nif.rs              # Erlang NIF bindings (rustler)
      wasm.rs             # WASM bindings (wasm-bindgen)
    tests/
      uniformity.rs       # Chi-squared uniformity tests
      determinism.rs      # Same input → same output
      consistency.rs      # Cross-platform consistency
    Cargo.toml
```

**React (Dashboard)**
```
  dashboard/
    src/
      components/
        experiments/       # List, Create, Detail, Results
        flags/             # Feature flag management
        metrics/           # Metric configuration
        admin/             # Tenant, API keys, users
        charts/            # Recharts wrappers for CI plots, lift curves
      hooks/               # TanStack Query hooks for API
      contexts/            # Auth, Tenant, WebSocket contexts
      pages/               # Route-level page components
      lib/
        api.ts             # API client (typed fetch wrapper)
        ws.ts              # Phoenix Channels client
        statistics.ts      # Client-side result formatting
    tests/
      e2e/                 # Playwright tests
      unit/                # Vitest component tests
```

### Docker Compose Configuration

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: experimenthub_dev
      POSTGRES_USER: experimenthub
      POSTGRES_PASSWORD: experimenthub_dev
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U experimenthub"]

  kafka:
    image: apache/kafka:3.7.0
    # KRaft mode (no Zookeeper)
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
    ports: ["9092:9092"]

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

  management_api:
    build: { context: ., dockerfile: apps/experiment_hub_web/Dockerfile }
    depends_on: [postgres, kafka, redis]
    ports: ["4000:4000"]
    environment:
      DATABASE_URL: ecto://experimenthub:experimenthub_dev@postgres/experimenthub_dev
      KAFKA_BROKERS: kafka:9092
      REDIS_URL: redis://redis:6379

  statistical_engine:
    build: { context: ., dockerfile: statistical_engine/Dockerfile }
    depends_on: [postgres]
    ports: ["8000:8000"]
    environment:
      DATABASE_URL: postgresql://experimenthub:experimenthub_dev@postgres/experimenthub_dev

  data_pipeline:
    build: { context: ., dockerfile: data_pipeline/Dockerfile }
    depends_on: [postgres, kafka]
    environment:
      DATABASE_URL: postgresql://experimenthub:experimenthub_dev@postgres/experimenthub_dev
      KAFKA_BROKERS: kafka:9092

  dashboard:
    build: { context: ., dockerfile: dashboard/Dockerfile }
    depends_on: [management_api]
    ports: ["3000:3000"]
```

---

## Phase 6: Verification & Quality Gates

**Command**: `/speckit.verify`

### Automated Verification

1. **Unit test pass rate**: 100% across all services
2. **Integration test suite**: Full experiment lifecycle (create → assign → event → analyze → conclude)
3. **Contract test suite**: All service-to-service contracts validated
4. **Property-based tests**: Assignment uniformity (chi-squared p > 0.05 on 100K samples)
5. **Statistical accuracy**: Results within 0.1% of scipy/PyMC reference on 5 benchmark datasets:
   - Equal conversion rates (should NOT declare winner)
   - Clear winner (10% vs 12% conversion, 10K samples per variant)
   - Small effect size (10% vs 10.5%, 100K samples)
   - Multiple variants (A/B/C/D)
   - Sequential analysis (early stopping correctness)
6. **Performance benchmarks** (k6 load tests):
   - Assignment: 10K rps, < 5ms p99
   - Event ingestion: 50K events/sec sustained for 5 minutes
   - Dashboard: < 2 sec query on 10M events
7. **Security scan**: No SQL injection, XSS, CSRF, broken auth (OWASP Top 10)
8. **Multi-tenancy isolation**: Tenant A operations never return tenant B data (automated fuzzing)

### Manual Verification (Quickstart Walkthrough)

Execute `quickstart.md` scenarios manually:
1. Create tenant, generate API key
2. Create experiment: "Checkout Button Color" (blue vs green) targeting 50/50 split
3. Simulate 10,000 users via SDK: 10% conversion for blue, 12% for green
4. Wait for data pipeline aggregation (< 2 minutes)
5. View dashboard: verify green shows as winner with > 95% confidence
6. Conclude experiment, verify audit log entry
7. Export results to CSV, verify data integrity
8. Create feature flag "new-checkout-flow", roll out to 10%, verify assignment rate

### Acceptance Criteria Validation

Map every acceptance scenario from spec.md to a passing test or manual verification result.

---

## Global Constraints & Instructions

### What to Generate in Each Phase

| Phase | Artifacts | Location |
|-------|-----------|----------|
| 0. Constitution | `constitution.md` | `specs/experimenthub/` |
| 1. Specification | `spec.md` | `specs/experimenthub/` |
| 2. Plan | `plan.md`, `data-model.md`, `research.md`, `quickstart.md`, `contracts/*.md` | `specs/experimenthub/` |
| 3. Tasks | `tasks.md` | `specs/experimenthub/` |
| 4. Analysis | `analysis-report.md` | `specs/experimenthub/` |
| 5. Implementation | Source code, tests, Docker configs, CI/CD | Repository root |
| 6. Verification | Test results, performance benchmarks, compliance report | `specs/experimenthub/verification/` |

### Cross-Cutting Concerns (Apply Throughout)

- **Git workflow**: Feature branch per phase, PR with constitution checklist
- **Commit convention**: `feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `chore:`
- **Documentation**: Every public function has docstrings. Every architectural decision has an ADR.
- **Error handling**: All errors are typed, logged, and return meaningful HTTP responses
- **Secrets management**: No hardcoded secrets. Environment variables or AWS Secrets Manager.
- **CORS**: Configurable allowed origins per tenant
- **Rate limiting**: Per API key, configurable limits stored in Redis

### Technology Version Pinning

```
Elixir: 1.16.x (OTP 26)
Python: 3.12.x
Rust: 1.75+ (2024 edition)
Node.js: 20 LTS
PostgreSQL: 16.x
Kafka: 3.7.x (KRaft)
Redis: 7.x
React: 18.x
TypeScript: 5.3+
Docker Compose: 3.8+
```

### Out of Scope for v1 (Explicitly Excluded)

- Mobile SDKs (iOS/Android)
- Server-side rendering for dashboard
- ML-based automated experiment optimization (bandits)
- Real-time streaming analytics (batch aggregation is sufficient)
- Custom visualization builder
- Slack/Teams integration for notifications
- Public API documentation portal (Swagger UI is sufficient)
- Internationalization (English only)

---

## Execution Instructions

**Execute phases sequentially. Each phase MUST produce complete artifacts before the next phase begins.**

1. Start with Phase 0 (Constitution) — establish principles
2. Phase 1 (Specify) — full PRD without any tech decisions
3. Phase 2 (Plan) — now map requirements to architecture, generate all supporting docs
4. Phase 3 (Tasks) — break plan into granular, parallelizable, dependency-ordered tasks
5. Phase 4 (Analyze) — validate cross-artifact consistency before writing code
6. Phase 5 (Implement) — TDD, service by service, following task order
7. Phase 6 (Verify) — automated tests, load tests, manual walkthrough

**After each phase, summarize what was produced and explicitly state readiness for the next phase.**

If any phase reveals ambiguities or conflicts with earlier phases, STOP and resolve them before proceeding. Update earlier artifacts if needed (SDD feedback loop).

**Begin with Phase 0: Constitution.**
