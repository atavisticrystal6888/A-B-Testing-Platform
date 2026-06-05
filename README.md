# ExperimentHub

ExperimentHub is a self-hosted experimentation platform built as a polyglot monorepo:

- Elixir umbrella for Management API, web layer, event collector, and assignment wrapper
- Rust assignment core for deterministic variant bucketing
- Python statistical engine and data pipeline workers
- React + TypeScript dashboard

## Current State

Implemented and integrated in this workspace:

- Experiment lifecycle APIs and domain models (experiments, variants, metrics, state transitions)
- Deterministic assignment flow with NIF-aware fallback path
- Event ingestion API and buffering pipeline scaffold
- Statistical engine and data pipeline scaffolding with tests/docs artifacts
- Dashboard pages for list/detail/create flows
- Auth/session integration across backend and dashboard
- Phoenix channel socket wiring for realtime dashboard updates

Recent integration fixes completed:

- Login now issues JWT session tokens (not Phoenix.Token) and supports tenant-aware or email-only login
- Session/API-key auth now both populate `current_scope` for controller consistency
- `/socket` endpoint mounted and dashboard websocket provider wired
- Legacy experiment pagination (`meta.total_count`) normalized for dashboard consumers
- Stale auth controller tests replaced with current auth contract coverage
- Compile-time warning hotspots reduced by removing direct hard references to unavailable Kafka/NIF modules

## Monorepo Layout

- Elixir apps: `apps/experiment_hub`, `apps/experiment_hub_web`, `apps/event_collector`, `apps/assignment_engine`
- Rust core: `assignment_core/`
- Dashboard: `dashboard/`
- Python services: `statistical_engine/`, `data_pipeline/`
- Specs and contracts: `specs/001-experimenthub-spec/`

## Documentation

- Full setup, deployment, architecture, features, and usage guide: `docs/setup-deployment-and-user-guide.md`

## Local Development

### 1) Start infrastructure

Development services:

```powershell
docker compose up -d
```

Ephemeral test services:

```powershell
docker compose -f docker-compose.test.yml up -d
```

### 2) Install deps

Elixir umbrella:

```powershell
mix deps.get
```

Dashboard:

```powershell
Set-Location dashboard
npm install
Set-Location ..
```

### 3) Bootstrap local admin

`mix setup` and `mix ecto.setup` now seed a default development account:

- Tenant: `Local Dev Tenant` (`local-dev`)
- Email: `admin@local.dev`
- Password: `ValidP@ssword123`

To recreate that account against an existing dev database:

```powershell
mix dev.bootstrap
```

### 4) Start application services

Phoenix now starts Oban normally once the database is migrated, so queued experiment analysis works in a regular dev boot.

Backend:

```powershell
mix phx.server
```

Statistical engine:

```powershell
Set-Location statistical_engine
pip install -e .
uvicorn src.api.main:app --host 127.0.0.1 --port 8000
Set-Location ..
```

### 5) Validate

Elixir compile:

```powershell
mix compile
```

Dashboard build:

```powershell
Set-Location dashboard
npm run build
Set-Location ..
```

Elixir tests:

```powershell
mix test
```

## Test Database Configuration

`config/test.exs` supports environment overrides:

- `DB_USERNAME` (default: `postgres`)
- `DB_PASSWORD` (default: `postgres`)
- `DB_HOST` (default: `localhost`)
- `DB_PORT` (default: `5432`)
- `DB_NAME` (default: `experiment_hub_test#{MIX_TEST_PARTITION}`)

## Known Environment Constraints

- Running tests requires PostgreSQL to be reachable from the configured test DB settings.
- Docker Desktop daemon must be running for `docker compose` workflows.
- Automatic experiment analysis requires both Oban-enabled Phoenix and the statistical engine on `http://127.0.0.1:8000`.
