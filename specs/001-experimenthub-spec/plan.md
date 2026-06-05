# Implementation Plan: ExperimentHub — A/B Testing & Experimentation Platform

**Branch**: `001-experimenthub-spec` | **Date**: 2026-04-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-experimenthub-spec/spec.md`

## Summary

ExperimentHub is a self-hosted, production-grade A/B Testing & Experimentation Platform composed of 5 core services: a Management API (Elixir/Phoenix) for experiment lifecycle, an Assignment Engine (Rust NIF + HTTP) for deterministic variant assignment via MurmurHash3, an Event Collector (Elixir/Broadway) for high-throughput event ingestion via Kafka, a Statistical Engine (Python/FastAPI) for frequentist + Bayesian analysis, and a Dashboard (React/TypeScript) for experiment management and results visualization. Multi-tenancy via PostgreSQL RLS, event sourcing via Kafka, and sub-5ms assignment latency are foundational constraints.

## Technical Context

**Language/Version**:
- Backend API/Real-time: Elixir 1.16+ / Erlang/OTP 26+ / Phoenix 1.7+
- Statistical Engine: Python 3.12+
- Assignment Library: Rust 1.75+ (compiled to WASM for browser, native NIF for BEAM)
- Dashboard Frontend: React 18+ with TypeScript 5.3+
- Data Pipeline Workers: Python 3.12+

**Primary Dependencies**:
- Elixir/Phoenix: Phoenix LiveView, Ecto 3.11+, Broadway + BroadwayKafka, Jason, Oban, NimbleOptions, Rustler, Elixlsx (Excel export)
- Python: FastAPI, scipy, numpy, pymc (Bayesian), pandas, confluent-kafka-python
- Rust: murmur3 (hashing), wasm-bindgen (WASM), rustler (Erlang NIF), serde
- React: React Router 6, TanStack Query 5, Recharts, shadcn/ui, Zod

**Storage**:
- PostgreSQL 16: Primary datastore (experiments, configs, results, tenants, audit logs). RLS for tenant isolation.
- Apache Kafka 3.7 (KRaft mode): Event streaming (assignments, metric events, lifecycle events). No Zookeeper.
- Redis 7: Assignment cache, rate limiting counters, session cache.

**Testing**:
- Elixir: ExUnit, Mox (external HTTP only), StreamData (property-based)
- Python: pytest, hypothesis (property-based), pytest-asyncio
- Rust: cargo test, proptest (property-based)
- React: Vitest, React Testing Library, Playwright (E2E)
- Integration: Docker Compose with real PostgreSQL + Kafka + Redis

**Target Platform**: Linux server (Docker containers). Browser SDK via WASM.
**Project Type**: Multi-service monorepo (Elixir umbrella + Python packages + Rust workspace + React app)

**Performance Goals**:
- Assignment: < 5ms p99 at 10K rps
- Event ingestion: 50K events/sec sustained
- Statistical computation: < 30 sec for 1M observations (Bayesian)
- Dashboard: < 2 sec page load with 10M+ events

**Constraints**:
- Max 5 services for v1 (Article VII)
- All data tenant-scoped via RLS (Article VIII)
- TDD mandatory: Red → Green → Refactor (Article III)
- No cross-service DB access (Article I)

**Scale/Scope**:
- v1: 5 tenants, 100 concurrent experiments, 10M events/day
- Design for 10× growth without architectural changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Article | Gate | Status | Notes |
|---------|------|--------|-------|
| I: Service-Oriented Modularity | ≤5 core services, clear boundaries, no cross-service DB access, background workers expose no API | **PASS** | 5 core services: Management API, Assignment Engine, Event Collector, Statistical Engine, Dashboard. Data Pipeline = background workers per Constitution v1.0.1 (not a discrete service; exposes no independent API). |
| II: Statistical Rigor | Frequentist + Bayesian, sequential analysis, auditable | **PASS** | Python statistical engine with scipy + pymc. All computations logged. Sequential analysis via O'Brien-Fleming. |
| III: Test-First Development | TDD, property-based tests, real DB in integration | **PASS** | ExUnit + StreamData, pytest + hypothesis, cargo test + proptest. Docker Compose for integration. |
| IV: Deterministic Assignment | Pure hash function, chi-squared verified, standalone library | **PASS** | Rust library with MurmurHash3. Packaged as: Rust crate, Elixir NIF (Rustler), WASM (wasm-bindgen). |
| V: Event Sourcing & Auditability | Kafka events, immutable audit log, reproducible results | **PASS** | All lifecycle/assignment/metric events flow through Kafka. PostgreSQL audit_logs table is append-only. |
| VI: Performance & Scalability | Meet all latency/throughput targets | **PASS** | Rust NIF for assignment (<5ms). Broadway for event ingestion (50K/s). PostgreSQL partitioning + materialized views for dashboard queries. |
| VII: Simplicity & YAGNI | No speculative features, no unnecessary abstractions, ≤5 core services (background workers excluded per Article I) | **PASS** | 5 core services (within cap). Every service maps to user stories. No wrapper patterns. Framework features used directly. |
| VIII: Multi-Tenancy | RLS, tenant context propagation, API key auth | **PASS** | PostgreSQL RLS policies on all tenant-scoped tables. Tenant context set at request boundary via Plug pipeline. |
| IX: Observability | JSON logging, health checks, metrics, tracing | **PASS** | Logger JSON backend, `/health` on all services, PromEx for Elixir metrics with `/metrics` HTTP endpoint, `/metrics` on FastAPI statistical engine, W3C trace context propagation. |

**Pre-research gate: PASS — all 9 articles satisfied.**

### Post-Design Re-Check (after Phase 1 artifacts)

| Article | Post-Design Verification | Status |
|---------|-------------------------|--------|
| I | Contracts defined for all 4 service boundaries (assignment-api, event-api, management-api, statistical-api). No cross-service DB access in data model. Statistical Engine reads from PostgreSQL rollup tables only (populated by Data Pipeline). | **PASS** |
| II | Statistical API contract defines full analysis response (p-value, CI, Bayesian posteriors, sequential analysis). `statistical_analyses` table logs all computation inputs/outputs. Research R2 confirms conjugate priors only (no MCMC) for v1. | **PASS** |
| III | Test frameworks specified per language. Property-based testing libraries included (StreamData, hypothesis, proptest). Docker Compose test environment defined. | **PASS** |
| IV | Research R1 confirms MurmurHash3. Data model shows `assignments` table for overrides only — hash computation is stateless. Rust library packaged as crate + NIF + WASM. Research R6 confirms NIF safety analysis. | **PASS** |
| V | Kafka topic schemas defined (4 topics). `audit_logs` table is append-only (REVOKE UPDATE/DELETE). `experiment_events_raw` partitioned by month. All lifecycle events flow through `experimenthub.lifecycle` topic. | **PASS** |
| VI | Research R3 validates Kafka partitioning (12 partitions for 50K events/sec). Research R4 validates PostgreSQL range partitioning for dashboard query performance. Research R6 confirms Rust NIF <5ms budget. k6 load test scenarios defined in quickstart. | **PASS** |
| VII | 5 core services (Data Pipeline = background workers, excluded from cap per Constitution v1.0.1 Article I — justified in Complexity Tracking). No abstract wrappers. Conjugate priors instead of MCMC (simpler). All choices traced to user stories. | **PASS** |
| VIII | RLS policies documented on every tenant-scoped table. `tenant_id` column on all data tables. Redis keys prefixed with `tenant_id`. API contracts show `X-API-Key` auth on all endpoints. Quickstart Scenario 4 validates cross-tenant isolation. | **PASS** |
| IX | Health check endpoints in all API contracts. Structured logging via Logger JSON backend. PromEx for Prometheus metrics with `/metrics` HTTP endpoint. FastAPI `/metrics` endpoint for statistical engine. W3C trace context headers documented. Cross-service tracing tasks (T336/T337) validate header propagation. | **PASS** |

**Post-design gate: PASS — all 9 articles satisfied after design phase.**

## Project Structure

### Documentation (this feature)

```text
specs/001-experimenthub-spec/
├── plan.md              # This file
├── research.md          # Phase 0: Technical research findings
├── data-model.md        # Phase 1: Entity-relationship model
├── quickstart.md        # Phase 1: Key validation scenarios
├── contracts/
│   ├── assignment-api.md    # OpenAPI 3.1 — Assignment endpoints
│   ├── event-api.md         # OpenAPI 3.1 — Event collection endpoints
│   ├── management-api.md    # OpenAPI 3.1 — CRUD operations
│   └── statistical-api.md   # OpenAPI 3.1 — Statistical engine endpoints
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
# Elixir Umbrella Application
apps/
├── experiment_hub/              # Core domain: Ecto schemas, business logic, contexts
│   ├── lib/experiment_hub/
│   │   ├── experiments/         # Experiment context (CRUD, state machine)
│   │   ├── assignments/         # Assignment context (NIF wrapper, caching)
│   │   ├── tenants/             # Tenant context (API keys, RBAC)
│   │   ├── metrics/             # Metric definitions context
│   │   ├── targeting/           # Targeting rules engine
│   │   └── audit/               # Audit log context
│   ├── priv/repo/migrations/    # Ecto migrations
│   └── test/
├── experiment_hub_web/          # Phoenix web layer
│   ├── lib/experiment_hub_web/
│   │   ├── controllers/         # REST API controllers
│   │   ├── channels/            # Phoenix Channels (live updates)
│   │   ├── plugs/               # Auth, tenant context, rate limiting
│   │   └── views/               # JSON views
│   └── test/
├── event_collector/             # Broadway-based event ingestion
│   ├── lib/event_collector/
│   │   ├── broadway/            # Broadway pipelines
│   │   ├── validation/          # Event schema validation
│   │   └── kafka/               # Kafka producer
│   └── test/
└── assignment_engine/           # Elixir NIF wrapper
    ├── lib/assignment_engine/
    │   └── native/              # Rustler NIF interface
    └── test/

# Rust Assignment Library
assignment_core/
├── src/
│   ├── lib.rs                   # Public API
│   ├── hash.rs                  # MurmurHash3 implementation
│   ├── assignment.rs            # Variant selection logic
│   ├── nif.rs                   # Erlang NIF bindings (Rustler)
│   └── wasm.rs                  # WASM bindings (wasm-bindgen)
├── tests/
│   ├── uniformity.rs            # Chi-squared distribution tests
│   ├── determinism.rs           # Same input → same output
│   └── cross_platform.rs        # WASM vs native consistency
└── Cargo.toml

# Python Statistical Engine
statistical_engine/
├── src/
│   ├── api/                     # FastAPI application
│   │   ├── main.py              # App entry point
│   │   ├── routes/              # Endpoint definitions
│   │   └── middleware/          # Auth, logging, tracing
│   ├── core/
│   │   ├── frequentist.py       # Z-test, Welch's t-test, chi-squared
│   │   ├── bayesian.py          # Beta-Binomial, Normal-Normal conjugate
│   │   ├── sequential.py        # Alpha-spending (O'Brien-Fleming)
│   │   └── power.py             # Sample size / power calculations
│   └── models/                  # Pydantic models
├── tests/
│   ├── test_frequentist.py      # Property-based tests vs scipy
│   ├── test_bayesian.py         # Tests vs PyMC reference
│   └── test_sequential.py       # Sequential analysis correctness
└── pyproject.toml

# Python Data Pipeline
data_pipeline/
├── src/
│   ├── consumers/               # Kafka consumers
│   ├── aggregators/             # Rollup computation
│   └── transforms/              # Data cleaning, bot filtering
├── tests/
└── pyproject.toml

# React Dashboard
dashboard/
├── src/
│   ├── components/
│   │   ├── experiments/         # List, Create wizard, Detail, Results
│   │   ├── flags/               # Feature flag management
│   │   ├── metrics/             # Metric configuration
│   │   ├── admin/               # Tenant, API keys, users
│   │   └── charts/              # CI plots, lift curves, funnels
│   ├── hooks/                   # TanStack Query hooks
│   ├── contexts/                # Auth, Tenant, WebSocket
│   ├── pages/                   # Route-level page components
│   └── lib/
│       ├── api.ts               # Typed API client
│       ├── ws.ts                # Phoenix Channels client
│       └── types.ts             # Shared TypeScript types
├── tests/
│   ├── e2e/                     # Playwright tests
│   └── unit/                    # Vitest component tests
├── package.json
└── tsconfig.json

# Infrastructure
docker-compose.yml               # PostgreSQL, Kafka (KRaft), Redis
docker-compose.test.yml          # Test environment with ephemeral containers
k6/                              # Load test scripts
├── assignment_load.js
├── event_ingestion_load.js
└── dashboard_load.js
```

**Structure Decision**: Multi-service monorepo using an Elixir umbrella application for the three BEAM-based services (Management API, Event Collector, Assignment Engine NIF wrapper), with the Rust assignment library, Python statistical engine, Python data pipeline, and React dashboard as sibling directories at the repository root. This structure keeps related Elixir code under a single `mix` umbrella while keeping polyglot services independent. Constitution v1.0.1 compliance: exactly 5 core services; Data Pipeline is classified as background workers (Article I) and excluded from the Article VII service cap.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 6th "service" (Data Pipeline) | Kafka consumers must aggregate raw events into PostgreSQL rollup tables for dashboard performance (NFR-003). | Data Pipeline runs as Python worker processes, not an independently-addressable HTTP service. It does not expose an API. Constitution v1.0.1 formally reclassified Data Pipeline as background workers (Article I) and excluded it from the Article VII 5-service cap. Shares the Statistical Engine's Python ecosystem. |
| Rust NIF in BEAM VM | Assignment must be < 5ms p99 (NFR-001). Pure Elixir hashing won't meet this at 10K rps. | Standalone HTTP microservice adds network latency (~1-2ms overhead), making the 5ms target harder to hit. Rust NIF via Rustler is the BEAM-endorsed approach for CPU-intensive, deterministic computations. |
| 5th Kafka topic (events.inbound) | Separates API write path (fire-and-forget to Kafka) from validation pipeline (Broadway consumer). Enables sub-10ms event API response latency (see Research R11). | Alternative: synchronous validation in the API request path adds latency and couples the API to DB availability. |
