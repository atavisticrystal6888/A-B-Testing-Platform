---
name: run-stack
description: >
  Start the local ExperimentHub development stack: Postgres/Kafka/Redis via
  docker compose, database setup + demo seed, Phoenix API server on :4000,
  and optionally the dashboard dev server. Use when asked to "run the app",
  "start the stack", or before manual/UI testing.
---

# Run the local stack

1. Infra: `docker compose up -d` at repo root; confirm health with
   `docker compose ps` (postgres:5432, kafka:9092, redis:6379 must be healthy).
2. Database: `mix ecto.setup` on first run, `mix ecto.migrate` afterwards.
3. Seed: `mix dev.demo` — creates tenant `local-dev`, admin login
   `admin@local.dev` / `ValidP@ssword123`, the `checkout_conversion` metric,
   and an SDK API key (capture the key from its output).
4. API: start `mix phx.server` **in the background** (Bash run_in_background),
   then poll `http://127.0.0.1:4000` until it responds. Never block the
   conversation on a foreground server.
5. Dashboard (when UI work/testing is involved): `npm run dev` in dashboard/
   in the background; note the Vite/dev URL it prints.

Give the user: URLs, the login credentials above, and the API key. On
teardown requests: stop background servers first, then
`docker compose down` (add `-v` only if the user explicitly wants data wiped).
