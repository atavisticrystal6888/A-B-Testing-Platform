---
name: e2e
description: >
  Run the full end-to-end experiment lifecycle test against a running (or
  freshly started) local stack: login, create experiment, start, assign a
  user, ingest conversion/revenue events, analyze, pause/resume, conclude.
  Use to verify the platform works end to end, e.g. before a release.
---

# End-to-end lifecycle test

Delegate to the `stack-e2e` agent — do not run the steps inline; the agent
owns stack bring-up, seeding, running `scripts/demo-e2e.ps1`, and teardown.

Pass along in the prompt:
- whether the stack is already up (skip bring-up) or must be started,
- the SDK API key if one is already known from this session,
- any extra assertions the user asked for.

Success criteria to enforce on the returned JSON summary:
- `assigned_variant` present (deterministic bucketing worked)
- `accepted_events` == 2 (both conversion and revenue ingested)
- `analysis_status` / `results_status` non-error
- pause → resume → conclude all report the expected statuses

If it fails, get the failing request + matching server log lines from the
agent, then debug in the main conversation. For load testing instead of a
lifecycle check, use the k6/ scripts, not this skill.
