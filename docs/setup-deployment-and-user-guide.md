# ExperimentHub Setup, Deployment, and User Guide

## 1. What ExperimentHub is

ExperimentHub is a self-hosted experimentation platform for teams that want to run A/B tests, multivariate tests, and feature rollouts without relying on a hosted SaaS product.

This repository is a polyglot monorepo made up of:

- An Elixir umbrella for the management API, authentication, experiment lifecycle, event collection, and web layer
- A Rust assignment core for deterministic user-to-variant bucketing
- A Python statistical engine for experiment analysis
- A React + TypeScript dashboard for day-to-day use
- An optional Python data pipeline package for background aggregation workers

The project is designed for organizations that want data sovereignty, tenant isolation, and control over the full experimentation stack.

## 2. What the project does today

### Core capabilities available in the current repository

- User login with tenant-aware JWT sessions
- Multi-tenant experiment management with role-based authorization
- Experiment creation, listing, detail views, and lifecycle transitions
- Deterministic assignment APIs for applications and SDKs
- Event ingestion APIs for single and batch experiment events
- Statistical analysis scheduling and persisted results retrieval
- Feature flag storage and evaluation APIs
- Metric definition CRUD APIs and experiment-metric attachment APIs
- Audit log queries and platform overview analytics
- Export and GDPR-related API endpoints
- Dashboard pages for login, overview, experiments, metrics, feature flags, and audit history
- WebSocket-driven dashboard refresh for experiment detail/result updates

### What the current dashboard exposes directly

- Login
- Platform overview dashboard
- Experiment list
- Experiment detail with start, pause, resume, and analysis actions
- Experiment creation wizard
- Metric definition list
- Feature flag list
- Audit log viewer

### Important current-state caveats

- The dashboard can create experiments, but metric creation and metric attachment still happen through the API.
- The Feature Flags page currently lists flags; the "Create Flag" button is present in the UI but is not wired into a completed flow.
- The dashboard does not currently expose a conclude-experiment action; concluding is available through the API.
- The repository contains controller modules for API keys and users, but those routes are not mounted in the main router right now. For now, create the first tenant user and API keys through Elixir console calls outside the dev bootstrap path.
- The repository ships Docker Compose files for infrastructure services only. It does not currently ship Dockerfiles for the Phoenix app, statistical engine, or dashboard.

## 3. How ExperimentHub works

At a high level, the system works like this:

1. A dashboard user signs in through the Phoenix API and receives a JWT.
2. Phoenix stores experiment, tenant, user, audit, and result data in PostgreSQL.
3. Tenant isolation is enforced in the backend using tenant-scoped data access and row-level isolation conventions.
4. Assignment requests go through the assignment endpoints, where the Rust assignment core is used for deterministic bucketing.
5. Redis is used for fast-path support such as assignment-related caching and rate-limiting support.
6. Event ingestion endpoints accept conversion or metric events and route them through the event-collection layer.
7. Kafka is part of the intended high-throughput event pipeline, and the event collector includes buffering behavior for Kafka outages.
8. Oban jobs schedule statistical analysis runs against the Python FastAPI statistical engine.
9. Analysis results are persisted back into PostgreSQL and exposed through result endpoints.
10. The React dashboard reads those APIs and uses a Phoenix socket connection to invalidate and refresh experiment detail data when updates arrive.

## 4. Architecture and responsibilities

### Elixir umbrella apps

- `apps/experiment_hub`: domain logic, repo, tenants, experiments, metrics, feature flags, workers
- `apps/experiment_hub_web`: Phoenix routing, controllers, auth, endpoint, websocket entry point
- `apps/event_collector`: event validation, buffering, Kafka-facing event handling
- `apps/assignment_engine`: assignment wrapper around the Rust core

### Rust

- `assignment_core`: deterministic assignment and hashing primitives

### Python

- `statistical_engine`: FastAPI service for frequentist and related analysis work
- `data_pipeline`: worker-oriented package for aggregation and pipeline tasks

### Frontend

- `dashboard`: separate React dashboard running in Vite during development and buildable as a static frontend for hosted deployment

## 5. Feature and functionality matrix

| Area | Current status | Primary access path | Notes |
| --- | --- | --- | --- |
| Authentication | Available | Dashboard + API | JWT login with optional tenant ID/slug |
| Tenant-aware experiments | Available | Dashboard + API | Create, list, view, start, pause, resume |
| Conclude experiment | Available | API | Not currently exposed in the dashboard UI |
| Assignment API | Available | API/SDK | Deterministic variant assignment |
| Event ingestion | Available | API/SDK | Single and batch event endpoints |
| Analysis scheduling | Available | Dashboard + API | Requires Phoenix with Oban plus statistical engine |
| Results viewing | Available | Dashboard + API | Pending state shown until analyses exist |
| Feature flags list/evaluate | Available | Dashboard + API | Dashboard is list-first; full management is API-oriented |
| Metric definition list | Available | Dashboard + API | CRUD is API-driven |
| Attach metrics to experiments | Available | API | Needed for meaningful experiment results |
| Audit logs | Available | Dashboard + API | Filterable in the UI |
| Platform analytics overview | Available | Dashboard + API | Current live endpoint is `/api/v1/analytics/overview` |
| Export results | Available | API | Export endpoints are present in Phoenix |
| GDPR export/erase | Available | API | API-only workflow |
| API key management | Partially present | Elixir console for now | Controller code exists, routes are not mounted |
| User management | Partially present | Elixir console for now | Controller code exists, routes are not mounted |

## 6. Local setup on a developer machine

This is the fastest reliable path for getting the full project running locally.

### Prerequisites

Install these first:

- Docker Desktop
- Elixir and Erlang/OTP compatible with the umbrella apps
- Node.js and npm
- Python 3.12+
- Rust and Cargo

The first build can take a little longer because the assignment core includes Rust code.

### Step 1: Start infrastructure

From the repository root:

```powershell
Set-Location "d:\Elixir\Elixir Major Project"
docker compose up -d
```

This starts:

- PostgreSQL on `localhost:5432`
- Kafka on `localhost:9092`
- Redis on `localhost:6379`

### Step 2: Install Elixir dependencies and prepare the database

```powershell
mix setup
```

What this does:

- Fetches Elixir dependencies
- Creates the development database
- Runs migrations
- Runs the development seed script

### Step 3: Install dashboard dependencies

```powershell
Push-Location dashboard
npm install
Pop-Location
```

### Step 4: Create a Python virtual environment for the statistical engine

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install --upgrade pip

Push-Location statistical_engine
..\.venv\Scripts\python -m pip install -e ".[dev]"
Pop-Location
```

Optional, only if you want the worker package installed too:

```powershell
Push-Location data_pipeline
..\.venv\Scripts\python -m pip install -e ".[dev]"
Pop-Location
```

### Step 5: Refresh the default development admin account

```powershell
mix dev.bootstrap
```

That command creates or refreshes the default local development tenant and admin account.

Default development login:

- Tenant slug: `local-dev`
- Email: `admin@local.dev`
- Password: `ValidP@ssword123`

### Step 6: Start the Phoenix backend

Use a new terminal in the repository root:

```powershell
Set-Location "d:\Elixir\Elixir Major Project"
mix phx.server
```

This starts the Phoenix API on `http://127.0.0.1:4000`.

### Step 7: Start the statistical engine

Use a second terminal:

```powershell
Set-Location "d:\Elixir\Elixir Major Project"
Push-Location statistical_engine
..\.venv\Scripts\python -m uvicorn src.api.main:app --host 127.0.0.1 --port 8000
```

The statistical engine health endpoint is:

- `http://127.0.0.1:8000/stats/v1/health`

### Step 8: Start the dashboard

Use a third terminal:

```powershell
Set-Location "d:\Elixir\Elixir Major Project"
Push-Location dashboard
npm run dev
```

The dashboard runs on:

- `http://127.0.0.1:3000`

In local dev, Vite proxies `/api` and `/v1` requests to Phoenix, so you do not need to set `VITE_API_URL`.

### Step 9: Verify the stack

Quick health checks:

```powershell
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:4000/health | Select-Object -ExpandProperty Content
Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/stats/v1/health | Select-Object -ExpandProperty Content
```

Then open the dashboard and sign in with the dev credentials.

### Step 10: What is optional vs required locally

- Required for login, dashboard browsing, and experiment CRUD: Phoenix, PostgreSQL, Redis
- Required for end-to-end analysis runs: Phoenix with Oban enabled plus the statistical engine
- Required for the intended high-throughput event path: Kafka in addition to the above
- Optional for basic local evaluation: `data_pipeline`

## 7. Web setup over the internet

ExperimentHub is a self-hosted codebase. There is no built-in hosted SaaS free tier and paid tier inside this repository.

For this guide, "free" and "paid" mean two deployment styles:

- Free/demo: lowest-cost public exposure for evaluation or an internal pilot
- Paid/production: hardened hosted deployment for real team use

### Recommended deployment shape

The cleanest hosted setup for the current repo is same-origin hosting:

- Serve the dashboard at `/`
- Proxy `/api`, `/v1`, and `/socket` to Phoenix
- Keep the statistical engine private on the same host or internal network

That avoids dashboard CORS problems and matches the current codebase better than a split-origin frontend.

### Option A: Free/demo web setup

Use this when you want to expose the app for testing, review, or a small internal demo.

#### Step 1: Choose a host

Use one of these:

- A spare machine you control
- A small free-tier or low-cost Linux VM
- Your own workstation plus a tunnel such as Cloudflare Tunnel or ngrok for a temporary public demo

#### Step 2: Install the same prerequisites as local setup

You still need:

- Elixir/Erlang
- Node.js
- Python 3.12+
- Rust/Cargo
- Docker or equivalent infrastructure services

#### Step 3: Start infrastructure services

From the repo root:

```bash
docker compose up -d
```

The current repository only provides Docker Compose for PostgreSQL, Kafka, and Redis. It does not provide application-service Dockerfiles yet.

#### Step 4: Build backend dependencies and database state

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
```

If you are deploying in `dev` for a short-lived demo, you can also run:

```bash
mix dev.bootstrap
```

That gives you the default dev admin account.

#### Step 5: Start the statistical engine on the same host

```bash
python -m venv .venv
. .venv/bin/activate
cd statistical_engine
pip install -e ".[dev]"
INTERNAL_API_KEY=dev-internal-key uvicorn src.api.main:app --host 127.0.0.1 --port 8000
```

Keeping the statistical engine on the same host is the easiest path because the Phoenix analysis worker defaults to `http://localhost:8000` and `dev-internal-key` unless you wire custom runtime config.

#### Step 6: Start Phoenix with public host configuration

For a simple hosted demo, set the required Phoenix env vars and run the app:

```bash
export PHX_SERVER=true
export PORT=4000
export PHX_HOST=your-public-host.example.com
export DATABASE_URL=ecto://experimenthub:experimenthub_dev@localhost/experiment_hub_dev
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export JWT_SECRET="replace-this-before-sharing-publicly"

MIX_ENV=prod mix phx.server
```

If your PostgreSQL deployment requires TLS, also set:

```bash
export DB_SSL=true
```

#### Step 7: Build the dashboard for the public API URL

The dashboard must know the public Phoenix base URL in hosted mode.

```bash
cd dashboard
npm install
VITE_API_URL=https://your-public-host.example.com npm run build
```

#### Step 8: Serve the dashboard and proxy API traffic

For a demo, you can serve the built dashboard with any static file server and reverse proxy `/api`, `/v1`, and `/socket` to Phoenix.

If you are using a tunnel-based demo, expose the dashboard host and keep Phoenix reachable behind the same public hostname through your proxy.

#### Step 9: First-user bootstrap for non-dev environments

There is no generic non-dev bootstrap task yet. For a hosted environment, create the first tenant, first admin user, and first API key from Elixir console:

```bash
MIX_ENV=prod iex -S mix
```

Then run:

```elixir
{:ok, tenant} = ExperimentHub.Tenants.create_tenant(%{
  "name" => "Acme Corp",
  "slug" => "acme"
})

{:ok, user} = ExperimentHub.Tenants.create_user(%{
  "tenant_id" => tenant.id,
  "email" => "admin@acme.example",
  "password" => "ChangeMe123!",
  "role" => "admin"
})

{:ok, api_key} = ExperimentHub.Tenants.create_api_key(%{
  "tenant_id" => tenant.id,
  "name" => "SDK Key"
})

api_key.raw_key
```

Important:

- Save `api_key.raw_key` immediately. The raw key is only available at creation time.
- Use the tenant slug or tenant ID at login time if the same email may exist in more than one tenant.

### Option B: Paid/production web setup

Use this when you want a real multi-user deployment with backups, TLS, monitoring, and more predictable uptime.

#### Step 1: Pick a production topology

Recommended current topology:

- Phoenix app on one VM or app host
- Statistical engine on the same private host or same VM
- PostgreSQL as either a managed instance or a private database host
- Redis as either managed or self-hosted
- Kafka only if you want the full event-ingestion path enabled exactly as designed
- Static dashboard files served through Nginx, Caddy, or another reverse proxy

#### Step 2: Provision production secrets

At minimum:

- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `JWT_SECRET`
- `PHX_HOST`
- `PORT`
- `POOL_SIZE`
- `DB_SSL` when your DB provider requires TLS

#### Step 3: Build Phoenix in production mode

```bash
mix deps.get
cd dashboard && npm install && cd ..
MIX_ENV=prod mix ecto.create
MIX_ENV=prod mix ecto.migrate
```

If you want the Phoenix app's own static assets built and digested, run the task from the Phoenix app directory:

```bash
cd apps/experiment_hub_web
MIX_ENV=prod mix assets.deploy
cd ../..
```

#### Step 4: Build the dashboard against the production API URL

```bash
cd dashboard
VITE_API_URL=https://app.example.com npm run build
```

#### Step 5: Start the statistical engine privately

If you keep it on the same host, the current defaults are enough for basic operation.

If you want to move it to another host or change the shared key, update the Phoenix runtime configuration so `:stat_engine_url` and `:stat_engine_api_key` are explicitly set. The current repository does not yet map those values from environment variables for you.

#### Step 6: Start Phoenix behind a reverse proxy

```bash
export PHX_SERVER=true
export PORT=4000
export PHX_HOST=app.example.com
export DATABASE_URL=ecto://USER:PASS@DBHOST/DBNAME
export SECRET_KEY_BASE="..."
export JWT_SECRET="..."
export POOL_SIZE=10
export DB_SSL=true

MIX_ENV=prod mix phx.server
```

#### Step 7: Use same-origin routing in your reverse proxy

Strongly recommended routing shape:

- `/` -> static dashboard build
- `/api` -> Phoenix
- `/v1` -> Phoenix
- `/socket` -> Phoenix websocket endpoint

This is the simplest production setup for the current frontend code.

#### Step 8: Add operational hardening

For a serious deployment, also add:

- TLS termination
- Process supervision or service management
- Database backups
- Log aggregation
- Metrics and uptime monitoring
- Secret rotation
- A real internal key for the statistical engine once runtime config is wired for it

## 8. Step-by-step usage guide

This section shows the most practical way to use the project in its current state.

### Step 1: Sign in to the dashboard

Open the dashboard and log in:

- Local URL: `http://127.0.0.1:3000/login`
- Dev tenant slug: `local-dev`
- Dev email: `admin@local.dev`
- Dev password: `ValidP@ssword123`

The tenant field is optional when the email only exists once. Use it when the same email exists across multiple tenants.

### Step 2: Review the platform dashboard

After login, the dashboard shows:

- Running, draft, paused, and concluded experiment counts
- Feature flag counts
- Assignment counts
- Recent experiments
- Recent audit activity

Use this page as the operational landing page.

### Step 3: Create an experiment in the dashboard

Go to `Experiments` -> `New Experiment`.

The wizard currently has four steps:

1. `Hypothesis`
2. `Variants`
3. `Traffic`
4. `Settings`

What to enter:

- Experiment name
- URL-safe experiment key
- Hypothesis
- Optional feature tag
- At least two variants, with exactly one control
- Traffic allocations that total 100%
- Optional schedule
- Optional targeting rules
- Optional mutual exclusion group selection

When the form succeeds, you are redirected to the experiment detail page.

### Step 4: Create a metric definition

The current dashboard lists metrics but does not create them. Create metrics through the API.

Example using the dashboard login token in PowerShell:

```powershell
$loginBody = @{
  tenant_id = 'local-dev'
  email = 'admin@local.dev'
  password = 'ValidP@ssword123'
} | ConvertTo-Json

$login = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/auth/login -ContentType 'application/json' -Body $loginBody
$token = $login.access_token

$metricBody = @{
  key = 'checkout_conversion'
  name = 'Checkout Conversion Rate'
  metric_type = 'count'
  definition = @{
    event_name = 'checkout_completed'
    event_type = 'conversion'
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/metric-definitions -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $metricBody
```

### Step 5: Attach the metric to an experiment

Attach a primary metric to the experiment you created:

```powershell
$attachBody = @{
  metric_definition_id = 'PUT-METRIC-DEFINITION-ID-HERE'
  role = 'primary'
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/experiments/PUT-EXPERIMENT-ID-HERE/metrics -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $attachBody
```

You can also attach guardrail metrics by supplying:

- `role = 'guardrail'`
- `guardrail_threshold`
- `guardrail_direction`

### Step 6: Start the experiment

From the experiment detail page, click `Start`.

You can also use the API:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/experiments/PUT-EXPERIMENT-ID-HERE/start -Headers @{ Authorization = "Bearer $token" }
```

### Step 7: Send assignment requests from your app

You can test assignment with either a JWT or an API key. For production SDK usage, an API key is the better fit.

Manual assignment example:

```powershell
$assignBody = @{
  user_id = 'user-123'
  experiment_key = 'checkout-button-color'
  attributes = @{
    country = 'US'
    device = 'mobile'
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/v1/assign -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $assignBody
```

For SDK-style integrations, also see:

- [docs/sdk/javascript-quickstart.md](./sdk/javascript-quickstart.md)
- [docs/sdk/elixir-quickstart.md](./sdk/elixir-quickstart.md)

### Step 8: Send experiment events

Once your application has a variant assignment, post events back to ExperimentHub:

```powershell
$eventBody = @{
  experiment_id = 'PUT-EXPERIMENT-ID-HERE'
  user_id = 'user-123'
  event_type = 'conversion'
  event_name = 'checkout_completed'
  value = 1
  timestamp = '2026-06-05T12:00:00Z'
  idempotency_key = 'evt-user-123-checkout-001'
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/v1/events -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $eventBody
```

Use `/v1/events/batch` when you want to post multiple events at once.

### Step 9: Run analysis and inspect results

If the experiment is running or paused and Phoenix has Oban plus the statistical engine available, you can trigger analysis:

- In the dashboard, use the `Run Analysis` button on the experiment detail page
- Or via API:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/experiments/PUT-EXPERIMENT-ID-HERE/analyze -Headers @{ Authorization = "Bearer $token" }
```

Then open the experiment detail page to inspect:

- Variant performance
- Sample sizes
- Conversion rates
- Statistical significance
- Confidence interval chart
- Conversion-over-time chart
- Guardrail breaches, when present

### Step 10: Pause, resume, or conclude the experiment

Pause and resume are available in the dashboard detail page.

Concluding is currently API-driven:

```powershell
$concludeBody = @{
  decision = 'ship_variant'
  rationale = 'Treatment outperformed control with sufficient evidence.'
} | ConvertTo-Json

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/experiments/PUT-EXPERIMENT-ID-HERE/conclude -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $concludeBody
```

### Step 11: Review audit history

Open the `Audit Log` page to inspect recorded changes.

You can filter by:

- Resource type
- Action type

The API also supports broader filters such as date ranges and resource IDs.

### Step 12: Use feature flags

Current practical workflow:

- List flags in the dashboard
- Create, update, and evaluate flags through the API

Example creation request:

```powershell
$flagBody = @{
  flag = @{
    key = 'new-checkout-flow'
    name = 'New Checkout Flow'
    description = 'Redesigned checkout experience'
    status = 'enabled'
    rollout_percentage = 2500
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/flags -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $flagBody
```

Example evaluation request:

```powershell
$evalBody = @{
  key = 'new-checkout-flow'
  context = @{
    user_id = 'user-123'
  }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post -Uri http://127.0.0.1:4000/api/v1/flags/evaluate -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body $evalBody
```

## 9. Recommended first-day workflow

If you want the shortest useful path for evaluating the project, do this in order:

1. Follow the local setup steps.
2. Sign in with the seeded local admin.
3. Create one experiment in the dashboard.
4. Create one metric definition through the API.
5. Attach that metric to the experiment.
6. Start the experiment.
7. Send a few assignment and event requests manually.
8. Trigger analysis.
9. Review the detail page and audit log.

## 10. Pointers to the rest of the repo docs

- General repo overview: [../README.md](../README.md)
- Public API overview: [./api-reference.md](./api-reference.md)
- JavaScript SDK quickstart: [./sdk/javascript-quickstart.md](./sdk/javascript-quickstart.md)
- Elixir SDK quickstart: [./sdk/elixir-quickstart.md](./sdk/elixir-quickstart.md)
- Product specification: [../specs/001-experimenthub-spec/spec.md](../specs/001-experimenthub-spec/spec.md)
- Validation scenarios: [../specs/001-experimenthub-spec/quickstart.md](../specs/001-experimenthub-spec/quickstart.md)

## 11. Summary

Use the local setup path when you want the fastest working environment.

Use the free/demo web path when you want to expose the app for evaluation without committing to a full production rollout.

Use the paid/production path when you want a durable self-hosted deployment, and keep the dashboard same-origin with Phoenix unless you are ready to explicitly wire CORS and cross-service runtime configuration.