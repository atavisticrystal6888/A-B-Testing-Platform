<!--
Sync Impact Report — v1.0.0 → v1.0.1 (PATCH)

Modified Principles:
  - Article I: "Service-Oriented Modularity" — reclassified Data Pipeline
    from discrete service to background workers; enumerated exactly 5 core
    services; added checklist item for background worker API prohibition.
  - Article VII: "Simplicity & YAGNI" — added cross-reference to Article I
    service list; clarified background workers excluded from cap; added
    checklist item for service count enforcement.

Added Sections: None
Removed Sections: None

Templates Requiring Updates:
  - .specify/templates/plan-template.md        ✅ no changes needed (generic)
  - .specify/templates/spec-template.md        ✅ no changes needed (generic)
  - .specify/templates/tasks-template.md       ✅ no changes needed (generic)
  - .specify/templates/checklist-template.md   ✅ no changes needed (generic)

Downstream Artifacts Already Aligned:
  - specs/001-experimenthub-spec/plan.md — already treats Data Pipeline as
    background workers (see Constitution Check and Complexity Tracking rows).
    No update required.

Follow-up TODOs: None
-->
# ExperimentHub Constitution

> **Version**: 1.0.1
> **Status**: Ratified
> **Created**: 2026-03-31
> **Last Amended**: 2026-04-01

This constitution establishes the immutable architectural principles governing the design, development, and operation of ExperimentHub — a self-hosted, production-grade A/B Testing & Experimentation Platform. All artifacts, code, and decisions must comply with these articles. The constitution supersedes all other documents.

---

## Article I: Service-Oriented Modularity

1. The platform is composed of **5 core services**: **Assignment Engine**, **Event Collector**, **Statistical Engine**, **Management API**, and **Dashboard UI**. The **Data Pipeline** is a set of background worker processes (not a discrete service); it does not expose an independent API and MUST NOT be counted toward the Article VII service cap.
2. Each core service has a clear boundary, owns its data, and communicates via defined contracts (REST APIs, Kafka topics, or direct function calls within the monorepo). Background workers (e.g., Data Pipeline) consume from Kafka and write to shared storage but are not independently addressable services.
3. No service may directly access another service's database tables. All inter-service data access must go through published APIs or shared event streams.
4. Service contracts (API schemas, Kafka topic schemas) must be defined and versioned before implementation begins.
5. Each core service must be independently testable, deployable, and replaceable without affecting other services.

### Compliance Checklist
- [ ] Service does not import or query another service's Ecto schemas or database tables directly.
- [ ] All inter-service communication uses a documented contract (OpenAPI spec or Kafka topic schema).
- [ ] Core service can start and pass its unit tests without other services running.
- [ ] No background worker process exposes an independently-addressable API.

---

## Article II: Statistical Rigor as a First-Class Citizen

1. All experiment conclusions **MUST** be backed by valid statistical methods (frequentist or Bayesian).
2. The platform **MUST NOT** declare a winner without reaching configured statistical significance thresholds.
3. Sample size calculations, power analysis, and multiple comparison corrections are mandatory, not optional features.
4. Every statistical computation must be auditable — inputs, methodology, parameters, and outputs are logged and persisted.
5. Sequential analysis with alpha-spending functions must be available to mitigate the peeking problem.
6. Statistical results must be reproducible: given the same input data and configuration, the engine must produce identical results.

### Compliance Checklist
- [ ] No code path declares an experiment winner without checking significance thresholds.
- [ ] Statistical functions log all inputs and outputs.
- [ ] Property-based tests validate statistical functions against reference implementations (scipy, R).
- [ ] Multiple comparison correction is applied when more than two variants exist.

---

## Article III: Test-First Development

1. TDD is non-negotiable. All implementation **MUST** follow **Red → Green → Refactor**.
2. No production code may be written without a corresponding failing test first.
3. Statistical functions require property-based testing (hypothesis testing with known distributions).
4. Integration tests must use real PostgreSQL and Kafka (via Docker), not mocks. Mocks are permitted only for external HTTP services.
5. Contract tests between services are mandatory before implementation of either side of the contract.
6. Test coverage is not a vanity metric — tests must be meaningful, testing behavior not implementation.

### Compliance Checklist
- [ ] Every PR includes tests written before or alongside the implementation.
- [ ] Integration tests run against real PostgreSQL (Docker).
- [ ] Contract tests exist for every inter-service API boundary.
- [ ] Statistical functions have property-based tests with known distributions.

---

## Article IV: Deterministic Assignment

1. User-to-variant assignment **MUST** be deterministic and reproducible given the same `(user_id, experiment_id)` pair.
2. Assignment must be consistent across requests — the same user must always receive the same variant for a given experiment (no flip-flopping).
3. The hashing algorithm must produce uniform distribution, verifiable by chi-squared goodness-of-fit tests (p > 0.05 on 100K+ samples).
4. Assignment logic must be extractable as a standalone library usable by any service in any language.
5. The assignment algorithm must support weighted traffic allocation (e.g., 80/20 splits) with verifiable distribution accuracy.
6. Assignment must be independent across experiments — a user's assignment in experiment A must not influence their assignment in experiment B (unless in a mutual exclusion group).

### Compliance Checklist
- [ ] Assignment function is pure: `f(user_id, experiment_id, variants, weights) → variant`. No side effects.
- [ ] Chi-squared uniformity tests pass with p > 0.05 on 100K+ samples.
- [ ] Same `(user_id, experiment_id)` always produces the same variant across restarts and deployments.
- [ ] Assignment library is packaged independently (Rust crate, WASM, Elixir NIF).

---

## Article V: Event Sourcing & Auditability

1. All experiment lifecycle events (created, started, paused, stopped, concluded) are immutable and append-only.
2. All assignment events and metric events flow through Kafka and are persisted to durable storage.
3. Any experiment result must be reproducible by replaying events from Kafka.
4. A complete audit trail records who changed what, when, and why for every experiment modification.
5. Audit log entries are immutable — they may not be updated or deleted (append-only).
6. Event schemas are versioned. Schema changes must be backward-compatible.

### Compliance Checklist
- [ ] No UPDATE or DELETE operations on audit log tables.
- [ ] All experiment state transitions produce a Kafka event.
- [ ] Audit log entries include: actor, action, timestamp, previous state, new state, reason.
- [ ] Event schemas have a version field and are backward-compatible.

---

## Article VI: Performance & Scalability

1. **Assignment endpoint**: < 5ms p99 latency at 10,000 requests/second.
2. **Event ingestion**: Handle 50,000 events/second sustained throughput via Kafka.
3. **Dashboard queries**: < 2 seconds for experiment results aggregation on 10M+ events.
4. **Statistical computations**: < 30 seconds for full Bayesian analysis on experiments with 1M+ observations.
5. Performance targets must be validated by automated load tests (k6 or equivalent) in CI.
6. The architecture must support 10× growth without fundamental redesign — horizontal scaling paths must be documented.

### Compliance Checklist
- [ ] Assignment endpoint benchmarked at 10K rps with p99 < 5ms.
- [ ] Event ingestion load test sustains 50K events/sec for 5+ minutes.
- [ ] Dashboard queries tested against 10M+ event datasets.
- [ ] Load test scripts are checked into the repository and run in CI.

---

## Article VII: Simplicity & YAGNI

1. Start with the simplest implementation that satisfies requirements.
2. No speculative features ("might need later"). Every feature must trace to a user story or functional requirement.
3. Maximum **5 core services** for v1 (see Article I for the enumerated list). Background worker processes (e.g., Data Pipeline) that do not expose independent APIs are not counted as services. Additional core services beyond 5 require a documented justification with rationale, impact analysis, and explicit approval.
4. Use framework features directly — no unnecessary abstraction layers, wrapper classes, or indirection.
5. Prefer standard library and well-known dependencies over custom implementations (except where domain-specific, e.g., assignment hashing).
6. Configuration over code: behavior that varies by environment should be configurable, not compiled.

### Compliance Checklist
- [ ] Every new module/service traces to a specific user story or FR.
- [ ] No abstract base classes or interfaces with a single implementation.
- [ ] No "util" or "helper" modules that grow unbounded.
- [ ] Framework features (Ecto, Phoenix, FastAPI) used directly without wrapping.
- [ ] Total core service count does not exceed 5; any new service has written justification.

---

## Article VIII: Multi-Tenancy from Day One

1. All data is tenant-scoped. No query may return cross-tenant data.
2. Tenant isolation at the database level via PostgreSQL Row-Level Security (RLS) policies.
3. Every API request must include tenant identification (via API key or JWT claim).
4. API authentication is per-tenant with API keys for programmatic access and optional JWT/OAuth for dashboard users.
5. Tenant context must be set at the beginning of every request and propagated through all downstream operations.
6. Tenant data deletion must be complete and verifiable (GDPR compliance).

### Compliance Checklist
- [ ] Every database query includes tenant scoping (enforced by RLS or application-level WHERE clause).
- [ ] Integration tests verify that Tenant A cannot read/write Tenant B data.
- [ ] API key validation extracts and sets tenant context before any business logic executes.
- [ ] Tenant deletion removes all associated data (experiments, events, results, audit logs).

---

## Article IX: Observability

1. **Structured logging** (JSON format) on every service. Logs must include: timestamp, level, service name, correlation ID, tenant ID, and message.
2. **Health check endpoints** (`GET /health`) on every service, returning service status and dependency health.
3. **Prometheus-compatible metrics** exposed by every service at `/metrics` endpoint.
4. **Distributed tracing** headers (W3C Trace Context or similar) propagated across all service boundaries.
5. Every error must be logged with sufficient context for diagnosis without requiring reproduction.
6. No `catch-all` error handlers that silently swallow exceptions.

### Compliance Checklist
- [ ] Service exposes `GET /health` with dependency checks.
- [ ] Service exposes `GET /metrics` with Prometheus-format metrics.
- [ ] All log entries are structured JSON with required fields (timestamp, level, service, correlation_id, tenant_id).
- [ ] Trace context headers are forwarded on all outbound HTTP requests.

---

## Governance

### Supremacy
This constitution supersedes all other documents, specifications, plans, and development practices. In case of conflict between any artifact and this constitution, the constitution prevails.

### Amendment Process
Amendments to this constitution require:
1. **Written rationale**: Why the amendment is necessary, with specific examples.
2. **Impact analysis**: Which existing artifacts, code, and tests are affected.
3. **Backward compatibility assessment**: Whether the amendment breaks existing guarantees.
4. **Explicit approval**: Documented sign-off before the amendment takes effect.

Amendments are appended to this document with a version number, date, and rationale. Previous articles are never deleted — they are superseded with a reference to the amendment.

### PR Compliance
All pull requests **MUST** include a constitution compliance checklist covering:
- [ ] Article I: Service boundaries respected, no cross-service DB access.
- [ ] Article II: Statistical methods validated, no premature winner declarations.
- [ ] Article III: Tests written first, integration tests use real dependencies.
- [ ] Article IV: Assignment determinism preserved, uniformity verified.
- [ ] Article V: Events are immutable, audit trail maintained.
- [ ] Article VI: Performance targets not degraded.
- [ ] Article VII: No speculative features, no unnecessary abstractions.
- [ ] Article VIII: Tenant isolation enforced, no cross-tenant data leaks.
- [ ] Article IX: Logging, health checks, metrics, and tracing in place.

---

## Amendment Log

| Version | Date | Article | Change | Rationale |
|---------|------|---------|--------|-----------|
| 1.0.0 | 2026-03-31 | All | Initial ratification | Establish governing principles for ExperimentHub v1 |
| 1.0.1 | 2026-04-01 | I, VII | Article I & VII alignment: reclassify Data Pipeline | Article I listed 6 discrete services contradicting Article VII's 5-service cap. Data Pipeline reclassified as background workers. Cross-references added between Articles I and VII. |
