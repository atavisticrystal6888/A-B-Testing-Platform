# ExperimentHub — Production Readiness Plan

_Compiled 2026-08-11 from a five-agent debugging sweep (Elixir umbrella, Rust
assignment_core, Python services, React dashboard, static production audit)._

## Where the platform stands

The core product is real, not scaffold: experiment lifecycle + variants +
metrics, deterministic assignment (Rust NIF with pure-Elixir fallback), JWT and
API-key auth with RBAC, Oban background jobs, frequentist/Bayesian/power/
sequential statistics, GDPR export, audit logs, k6 load-test scenarios, and a
fully green React dashboard (typecheck, lint, tests, prod build).

Verified green at time of audit:

| Subsystem | Build | Tests | Lint |
|---|---|---|---|
| Rust `assignment_core` | ✅ (0 warnings after fix) | ✅ 12/12 incl. proptests | ✅ clippy clean |
| Python `statistical_engine` | ✅ | ✅ 55/55 | ✅ ruff (28 mypy annotation errors) |
| Python `data_pipeline` | ✅ | ✅ 5/5 (consumer untested) | ✅ ruff (14 mypy errors) |
| React `dashboard` | ✅ prod build | ✅ 7/7 unit (e2e needs backend) | ✅ tsc + eslint clean |
| Elixir umbrella | 3 compile warnings | see Elixir section | credo pending |

## P0 — correctness & tenant safety (must fix before any production use)

1. **Assignment hash divergence (latent experiment-corrupting bug).** Rust NIF
   buckets via MurmurHash3 x64_128 (`assignment_core/src/hash.rs`); the
   pure-Elixir fallback uses SHA-256
   (`apps/assignment_engine/lib/assignment_engine/native.ex:22`). Each path is
   deterministic, but they disagree — enabling `ASSIGNMENT_ENGINE_BUILD_NIF`
   in production would silently re-bucket every user. Fix: make the Elixir
   fallback implement the same MurmurHash3 bucketing and add a cross-impl
   parity test (golden vectors generated from the Rust crate).
2. **Row-level security covers 2 of ~20 tenant tables** (`users`, `api_keys`
   only; migration `20260401000004` claims "all"). Extend RLS to experiments,
   variants, metrics, assignments, events, analyses, audit_logs, etc., and fix
   the misleading comment.
3. **Kafka producer is a stub.** `apps/event_collector/lib/event_collector/kafka/client.ex`
   returns `:ignore`; events only ever reach the disk buffer. Implement a real
   producer (brod or broadway_kafka's producer), enable the Broadway consumer
   pipeline, and add an integration test against compose Kafka.
4. **data_pipeline never persists rollups** — consumer created a fresh
   aggregator per event and never flushed; `metric_definition_id` was inserted
   as NULL (breaking the upsert's ON CONFLICT dedup). _Fix in progress:_
   single owned aggregator, count/time-based flush + flush-on-stop,
   event_name → metric_definition_id resolution, compose-aligned DB default,
   consumer tests, mypy clean.
5. **`httpx2` dependency** — removed pending verification. Starlette 1.6's
   TestClient imports `httpx2`; the installed starlette wheel is hash-clean,
   so this may be a legitimate httpx successor rather than a typosquat.
   Restore (with a sane version pin) or keep removed once verified against
   PyPI/encode sources.

## P1 — production infrastructure

6. **CI/CD**: `.github/workflows/` does not exist. Add a pipeline: Elixir
   compile+test (+credo), cargo test+clippy, pytest ×2, dashboard
   tsc/lint/test/build, then container builds; k6 smoke on a schedule or
   release tag (spec Article VI requires load tests in CI).
7. **Prometheus `/metrics` endpoint** (spec Article IX): telemetry deps exist
   but no exporter; add `prom_ex` (or `telemetry_metrics_prometheus`) to
   `experiment_hub_web`.
8. **Containerization gaps**: no Dockerfile for `data_pipeline`; release
   compose references services dev compose lacks; neither Python service is
   composed. Align `docker-compose*.yml`, add the missing Dockerfile, and
   compose the Python services.
9. **TLS & secrets**: SSL block in `config/runtime.exs` is commented out —
   document/enforce HTTPS at the LB or via `force_ssl`; make JWT TTL
   env-configurable (`session_auth.ex` hardcodes 86_400s); stats engine
   `INTERNAL_API_KEY` must be required outside dev (warning added; enforce in
   release env docs). CORS wildcard default fixed → dev-origins default.
10. **Health checks**: extend `/health` to report Postgres/Redis/Kafka
    connectivity; wire into compose healthchecks and CI smoke.

## P2 — hardening & polish

11. Dashboard auth: JWT in localStorage with no refresh flow (sessions die
    silently at expiry; XSS-exfiltratable). Add refresh-token rotation or
    httpOnly-cookie sessions; stop passing the JWT as a WS query param.
12. `VITE_API_URL` is baked at Docker build time — switch to runtime config
    (env.js injected by nginx entrypoint) so one image serves all envs.
13. Feature-flag detail click-through is a `console.log` stub
    (`FeatureFlagsPage.tsx:39`) — wire or remove.
14. Split the 396 kB `ExperimentDetailPage` chunk (Recharts) if load time
    matters.
15. mypy annotation debt: 28 errors in statistical_engine, remainder in
    data_pipeline after the P0 fix.
16. Structured JSON logging with correlation/tenant fields across services
    (spec Article IX); W3C trace context currently Python-only.
17. Elixir compile warnings (3) — details pending the umbrella report; drive
    to `--warnings-as-errors` clean and keep it that way in CI.

## Verification strategy

- Per-subsystem QA delegated to the new project agents in `.claude/agents/`
  (elixir-qa, rust-qa, python-qa, dashboard-qa), orchestrated by the
  `/qa-all` skill.
- End-to-end: `/e2e` skill → `stack-e2e` agent (compose infra → `mix ecto.setup`
  → `mix dev.demo` → `mix phx.server` → `scripts/demo-e2e.ps1` full lifecycle).
- Dashboard e2e: Playwright suite against the live stack; manual UI/UX pass on
  login → experiment create → start → results → conclude.
- Load: k6 scenarios against the composed stack (release gate, not per-PR).

## Sequencing / status (updated 2026-08-12)

- ✅ Wave 1: Rust warning; httpx2 verified LEGITIMATE (Pydantic-stewarded httpx
  successor, restored); CORS default; ws logging; data_pipeline consumer fix
  (15/15 tests, mypy/ruff clean).
- ✅ Wave 2: hash parity across all THREE implementations (Rust Murmur, native.ex
  was SHA-256, assignments.ex elixir_assign was MD5) with golden-vector parity
  test; all 5 compile warnings; credo dep + umbrella-aware .credo.exs; JWT_SECRET
  boot validation; pbkdf2 test rounds.
- ✅ Wave 2b (found during work): SDK feature-flag evaluation always returned
  false (Evaluator checked nonexistent status "active"); consolidated three
  divergent evaluation implementations into FlagTargeting; 14/14 flag tests.
- ✅ Wave 3: Kafka producer via :brod (disk-buffer fallback preserved), Broadway
  consumer enabled dev/prod (KAFKA_CONSUMER_ENABLED), live round-trip integration
  test, full umbrella 251/251. RLS migration 20260401000023 (6 missing policies,
  FORCE on 15 tables, rollback verified, isolation regression test).
  Windows-only caveat: crc32cer NIF DLL hand-built locally (deps wipe requires
  rebuild; Docker/Linux unaffected).
- ✅ Wave 4: CI (.github/workflows/ci.yml), data_pipeline Dockerfile, release
  compose fixes + data-pipeline service, dashboard runtime env.js config,
  flag detail panel, Recharts lazy split (396 kB → 12.8 kB page chunk).
- 🔄 Wave 5 (in flight): Prometheus /metrics + audit_logs partition-manager fix.
- ⏳ Wave 6: e2e lifecycle (stack-e2e), Playwright, manual UI/UX pass, k6, final
  /qa-all gate.

Deferred (documented, not blocking): TLS termination guidance, JWT TTL env
config, dashboard refresh-token flow, structured JSON logging unification,
mypy annotation debt in statistical_engine.
