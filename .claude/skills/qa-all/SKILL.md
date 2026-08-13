---
name: qa-all
description: >
  Run the full QA sweep across every subsystem of the ExperimentHub monorepo
  in parallel — Elixir umbrella, Rust assignment_core, Python services, and
  the React dashboard — and merge the results into one verdict. Use before
  a release, after a large change, or when asked "is the repo green?".
---

# Full-repo QA sweep

Launch the four QA subagents **in parallel** (one Agent-tool message, four
calls), then merge their reports:

1. `elixir-qa` — compile --warnings-as-errors, mix test, credo
2. `rust-qa` — cargo build/test/clippy on assignment_core
3. `python-qa` — pytest for statistical_engine and data_pipeline
4. `dashboard-qa` — tsc, lint, tests, production build

Ask each for its standard distilled report. While they run, do not duplicate
their work in the main conversation.

Merge rules:
- Overall verdict is SHIPPABLE only if all four report SHIPPABLE.
- Present one combined table: subsystem | build | tests | lint | verdict.
- List every NEEDS-FIXES item as `subsystem file:line — cause`, ordered by
  severity (compile errors > test failures > warnings > lint).
- If two subsystems fail on the same contract (e.g. an API shape shared by
  Phoenix and the dashboard), call that out as one root cause, not two bugs.

If the user asked for fixes (not just status), fix top-severity items in the
main conversation, then re-run only the affected QA agent(s) to confirm.
