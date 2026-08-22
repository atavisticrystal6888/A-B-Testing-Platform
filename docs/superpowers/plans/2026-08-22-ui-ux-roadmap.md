# Post-v1.0 UI/UX Roadmap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship all 12 items of `docs/ui-ux-roadmap.md` (decision panel, SRM, timeline, days-to-significance, power calculator, cohort chips, shareable readout, launch checklist, error boundaries, responsive layout, a11y, stats tooltips).

**Architecture:** Mostly presentation-layer work on the React dashboard, backed by three thin backend additions: an Elixir timeline endpoint (audit lifecycle + daily exposures), a days-to-significance projection in the Python analyze path (fed an exposure rate by Elixir), an Elixir power-estimate proxy, and a stored-HTML shareable-readout route behind Phoenix.Token.

**Tech Stack:** React 18 + Vite + Tailwind v4 + TanStack Query + Recharts + vitest/RTL (dashboard); Phoenix 1.8 + Ecto + Req (Elixir); FastAPI + scipy + pytest (Python).

**Spec:** `docs/ui-ux-roadmap.md` plus the item-level acceptance criteria in the driving prompt (restated inline per task below).

## Global Constraints

- NEVER touch the bucketing contract (Murmur3 x64_128, ":" separator, mod 10_000). Golden vector tests in `assignment_core/tests/assignment_test.rs` and `apps/assignment_engine/test/assignment_engine/native_test.exs` must keep passing.
- ratio/funnel metric types stay rejected ("not yet supported") on primary AND guardrail paths in `statistical_engine/src/api/routes/analysis.py:176-184` and `:334-352`. Do not route them to the z-test.
- `frequentist.effect_size.relative` must remain present in the analyze response (consumed by `ExperimentHub.Metrics.GuardrailEvaluator`).
- `dashboard/src/lib/readout.ts` stays dependency-free and self-contained (imports nothing; other modules may import FROM it).
- Match idioms: Tailwind v4 utilities inline (buttons `px-4 py-2 bg-indigo-600 text-white rounded-lg`, cards `bg-white rounded-xl border border-gray-200`), TanStack Query for data, Recharts for charts.
- Do NOT run repo-wide `mix format --check-formatted`; run `mix format path/to/file.ex` only on files you touch.
- Git: stage by explicit path only (NEVER `add -A`, `add .`, `commit -a`). One commit per task, message prefixed `Roadmap #N:`. No release tags.
- Dashboard commands run from `dashboard/`: `npm test` (vitest run), `npm run build`. Elixir tests: `mix test path/to/test.exs` from repo root. Python: `pytest tests/...` from `statistical_engine/`.
- Before writing dashboard code that consumes analysis results, read `dashboard/src/lib/types.ts` (~lines 150-230) and verify exact field names; the shapes below were scouted but field-verify before use.

---

### Task 1: Roadmap #1 — Plain-language decision panel

**Files:**
- Modify: `dashboard/src/lib/readout.ts` (add exported `deriveDecision` + decision section in HTML)
- Create: `dashboard/src/components/experiments/DecisionPanel.tsx`
- Modify: `dashboard/src/pages/ExperimentDetailPage.tsx` (render DecisionPanel above SignificanceCard)
- Test: `dashboard/tests/lib/decision.test.ts`

**Interfaces:**
- Produces: `deriveDecision(experiment: Experiment, results: AnalysisResults): Decision | null` exported from `lib/readout.ts`, where `Decision = { state: "ship" | "do_not_ship" | "keep_collecting" | "no_effect"; headline: string; detail: string }`.
- readout.ts stays import-free: the function lives THERE; `DecisionPanel.tsx` imports it from `../../lib/readout`.

**Decision mapping (authoritative — exactly four states):**
1. Primary metric significant (p < 0.05), positive relative effect, no guardrail breach → `ship`, headline `Ship <variant name>` (winner = treatment variant of the primary comparison; if not identifiable from the metric result, use the experiment's first non-control variant name).
2. Any guardrail breach (`results.guardrail_breaches` non-empty OR any metric `guardrail_status.is_breached`) → `do_not_ship`, headline "Do not ship", detail names the breached metric(s). Breach wins over everything. A significant *negative* primary effect with no breach also maps to `do_not_ship` (detail: primary metric regressed significantly).
3. Not significant + underpowered (`sample_size_calculation.is_sufficient === false`, falling back to `power_achieved < 0.8`) → `keep_collecting`, detail includes current vs required sample size when available.
4. Not significant + adequately powered → `no_effect` ("No detectable effect").
- Return `null` when there is no primary metric result or no frequentist block (panel simply not rendered). Presentation only — no new math.

- [ ] **Step 1: Write failing tests** in `dashboard/tests/lib/decision.test.ts` — one test per state plus the null case and the significant-negative case. Build minimal `AnalysisResults` fixtures matching `lib/types.ts` exactly (verify field names first: `metrics[].frequentist.p_value`, `.effect_size.relative`, `.power_achieved`, `sample_size_calculation`, `guardrail_status.is_breached`, `results.guardrail_breaches`). Example:

```ts
import { deriveDecision } from "../../src/lib/readout";

it("maps significant improvement + clean guardrails to ship", () => {
  const d = deriveDecision(exp({ variants: ["control", "variant-b"] }), results({
    p_value: 0.01, relative: 0.12, is_sufficient: true, breaches: [],
  }));
  expect(d).toMatchObject({ state: "ship" });
  expect(d!.headline).toContain("variant-b");
});
```

- [ ] **Step 2:** `cd dashboard && npx vitest run tests/lib/decision.test.ts` — expect FAIL (deriveDecision not exported).
- [ ] **Step 3:** Implement `deriveDecision` in `readout.ts` (pure, no imports). Then add a decision section to `buildReadoutHtml` output: rendered FIRST, before metric sections — a colored banner div (green for ship, red for do_not_ship, amber for keep_collecting, gray for no_effect) with headline + detail, using the same inline-CSS style the file already uses.
- [ ] **Step 4:** Implement `DecisionPanel.tsx`: takes `{ experiment, results }`, calls `deriveDecision`, renders nothing on null; otherwise a full-width card above the stats: state-colored left border (`border-l-4`), headline in `text-lg font-semibold`, detail in `text-sm text-gray-600`, small uppercase label "Recommendation". Wire into `ExperimentDetailPage.tsx` directly above `SignificanceCard`.
- [ ] **Step 5:** `npx vitest run tests/lib/decision.test.ts` — PASS. Then `npx vitest run` (full suite) — no regressions.
- [ ] **Step 6:** Commit: `git add dashboard/src/lib/readout.ts dashboard/src/components/experiments/DecisionPanel.tsx dashboard/src/pages/ExperimentDetailPage.tsx dashboard/tests/lib/decision.test.ts` then `git commit -m "Roadmap #1: plain-language decision panel on detail page and readout"` (body: note the significant-negative→do_not_ship product call).

### Task 2: Roadmap #2 — SRM diagnostics banner

**Files:**
- Create: `dashboard/src/lib/srm.ts`
- Create: `dashboard/src/components/experiments/SrmWarningBanner.tsx`
- Modify: `dashboard/src/pages/ExperimentDetailPage.tsx`
- Test: `dashboard/tests/lib/srm.test.ts`

**Interfaces:**
- Produces: `chiSquareSf(x: number, df: number): number` and `computeSrm(observed: number[], expectedWeights: number[]): { chi2: number; pValue: number; observed: number[]; expected: number[] } | null` from `lib/srm.ts`; `SRM_P_THRESHOLD = 0.001`.
- Consumes: per-variant `sample_size` from the primary metric's variant stats in `AnalysisResults` (these counts originate from `Metrics.AnalysisData.variant_stats/2`, satisfying the acceptance criterion) and `experiment.variants[].traffic_allocation` (basis points, 0–10000).

**Math:** chi-square survival function via regularized upper incomplete gamma Q(df/2, x/2): series expansion for x < df/2 + 1, Lentz continued fraction otherwise, Lanczos log-gamma. ~40 lines, no dependencies. `computeSrm` returns null if any expected count < 5 or total observed < 100 (too early to call SRM). Expected weights normalized over the variants present (allocations may not sum to 10000 under partial rollout).

- [ ] **Step 1: Failing tests** in `tests/lib/srm.test.ts` with golden values: `chiSquareSf(3.841, 1)` ≈ 0.05 (±0.001), `chiSquareSf(10.828, 1)` ≈ 0.001, `chiSquareSf(13.816, 2)` ≈ 0.001, `chiSquareSf(0, 3)` = 1. `computeSrm([5000, 5000], [5000, 5000])` p ≈ 1; `computeSrm([5400, 4600], [5000, 5000])` p < 0.001 (chi2 = 64); `computeSrm([30, 30], [...])` → null (below floor).
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement `srm.ts`. **Step 4:** Run — PASS.
- [ ] **Step 5:** `SrmWarningBanner.tsx`: props `{ experiment, results }`. Extract primary-metric per-variant sample sizes + allocations; if `computeSrm` fires below `SRM_P_THRESHOLD`, render an amber warning banner (`bg-amber-50 border border-amber-300 rounded-lg p-4`): "**Sample ratio mismatch detected** — observed split {a}% / {b}% differs from the configured {x}% / {y}% (p = {p}). Results may not be trustworthy; check your SDK integration and targeting rules." List every variant's observed vs expected percentage. Dismissible (X button) — persist dismissal in `localStorage` under `srm-dismissed:{experimentId}:{results.computed_at}` so a NEW analysis re-raises it. Never blocks anything. Render near the top of `ExperimentDetailPage` (above DecisionPanel).
- [ ] **Step 6:** Full `npx vitest run` — green. Commit the four files: `Roadmap #2: SRM chi-square diagnostics banner` (body: client-side computation from AnalysisData-derived counts; null below n=100/expected<5 floor).

### Task 3: Roadmap #3 — Experiment timeline route

**Files:**
- Create: `apps/experiment_hub_web/lib/experiment_hub_web/controllers/timeline_controller.ex`
- Modify: `apps/experiment_hub_web/lib/experiment_hub_web/router.ex` (inside the authenticated `/api/v1` scope: `get "/experiments/:experiment_id/timeline", TimelineController, :show`)
- Test: `apps/experiment_hub_web/test/experiment_hub_web/controllers/timeline_controller_test.exs`
- Create: `dashboard/src/pages/ExperimentTimelinePage.tsx`
- Modify: `dashboard/src/App.tsx` (route `/experiments/:id/timeline`), `dashboard/src/pages/ExperimentDetailPage.tsx` (add "Timeline" link next to the action buttons)
- Reuse: `dashboard/src/components/charts/TimelineChart.tsx` (orphaned; kept for this purpose)

**Interfaces:**
- Produces: `GET /api/v1/experiments/:experiment_id/timeline` → `{ "data": { "lifecycle": [{ "action": "start", "at": iso8601, "actor_type": "user", "reason": null }], "daily_exposures": [{ "date": "2026-08-01", "count": 123 }] } }`. Lifecycle = audit-log entries for the experiment whose action is one of create/start/pause/resume/conclude (source of truth per acceptance criteria). Daily exposures = assignments grouped by `date(assigned_at)` (verify the Assignment schema module name/fields before writing the query — see `ExperimentHub.Metrics.AnalysisData` at `apps/experiment_hub/lib/experiment_hub/metrics/analysis_data.ex` for how it queries assignments, and reuse that schema).

- [ ] **Step 1: Failing controller test.** Use `ConnCase` + fixtures (`tenant_fixture`, `experiment_fixture`, `variant_fixture`, api-key auth header per `api_key_controller_test.exs` idiom). Seed: two assignments on different days (insert directly via Repo with explicit `assigned_at`), one audit entry via `ExperimentHub.AuditLog.log_experiment_change/3` with action "start". Assert 200, lifecycle contains the start entry, daily_exposures has two rows with correct counts, and a different tenant's key gets 404.
- [ ] **Step 2:** `mix test apps/experiment_hub_web/test/experiment_hub_web/controllers/timeline_controller_test.exs` — FAIL (route/controller missing).
- [ ] **Step 3:** Implement controller: fetch experiment scoped to `conn.assigns` tenant (follow `ResultsController`'s scoping idiom exactly), 404 if absent; query audit logs via the existing `AuditLog` context function used by `AuditLogController.list_for_resource`, filter to the five lifecycle actions; group assignments by date with an Ecto `fragment("date(assigned_at)")` query. Add router line. `mix format` the two touched files.
- [ ] **Step 4:** Test — PASS. Dispatch **elixir-qa** agent; must come back green.
- [ ] **Step 5: Frontend.** `ExperimentTimelinePage.tsx`: fetch experiment (`useExperiment(id)`) + new query `["timeline", id]` → `api.get(`/api/v1/experiments/${id}/timeline`)`. Layout: page header (experiment name, "Timeline", back-link to detail); TimelineChart fed `[{ id, name, status, started_at, ended_at, feature_tag }]` from the experiment (its existing `TimelineExperiment[]` prop shape — adapt data to it, do not rewrite the chart); below it a cumulative-exposures Recharts `AreaChart` (accumulate `daily_exposures` client-side) with vertical `ReferenceLine`s at each lifecycle event, labeled with the action; below that a plain list of lifecycle events (action, timestamp, actor_type, reason). Loading/error/empty states per existing idiom. Register lazy route in `App.tsx`; add "Timeline" link on the detail page header.
- [ ] **Step 6:** `npx vitest run` + `npm run build` clean (or dispatch **dashboard-qa**). Commit all six files: `Roadmap #3: experiment timeline route (audit lifecycle + cumulative exposures)`.

### Task 4: Roadmap #4 — Days-to-significance estimate

**Files:**
- Create: `statistical_engine/src/core/projection.py`; Test: `statistical_engine/tests/test_projection.py`
- Modify: `statistical_engine/src/api/models/analysis.py` (add `exposure_rate_per_day: float | None = None` to `AnalysisConfig`; add optional `projection` field to `MetricResult`), `statistical_engine/src/api/routes/analysis.py` (attach projection for primary metrics)
- Modify: `apps/experiment_hub/lib/experiment_hub/workers/analysis_worker.ex` (compute + send exposure_rate_per_day), `apps/experiment_hub_web/lib/experiment_hub_web/controllers/experiment_controller.ex` index JSON (surface latest primary projection per experiment)
- Modify: `dashboard/src/lib/types.ts`, `dashboard/src/pages/ExperimentDetailPage.tsx`, `dashboard/src/pages/ExperimentListPage.tsx`

**Interfaces:**
- Produces (Python): `project_days_to_significance(minimum_required_per_variant, current_total, num_variants, exposure_rate_per_day) -> dict` returning `{"status": "estimate", "days_remaining": int}` | `{"status": "may_never", "days_remaining": None}` | `{"status": "insufficient_data", "days_remaining": None}`. Attached to `MetricResult.projection` only when the request supplies a positive exposure rate. Reuses the already-computed `sample_size_calculation` (power.py) — no new statistics.
- Rules: rate ≤ 0 or missing required-n → insufficient_data; remaining ≤ 0 → estimate/0 days; `days = ceil((minimum_required_per_variant * num_variants - current_total) / rate)`; days > 365 → may_never ("may never reach significance at current traffic"). NEVER emit a calendar date (no false precision).
- Produces (Elixir): `exposure_rate_per_day` = assignments in the last 7 days (or since `started_at` if the experiment is younger) ÷ that window in days, added to the analyze request `config`. Experiments index JSON gains `"days_to_significance": {"status": ..., "days_remaining": ...} | null` read from the latest persisted `StatisticalAnalysis.results` primary metric (nil-safe `get_in`).
- Produces (dashboard): detail page line under the significance card and a "Time to significance" column in the list — "~N days" / "may never reach significance at current traffic" / "—".

- [ ] **Step 1 (TDD, Python):** `tests/test_projection.py`: estimate case (required 10_000/variant, 2 variants, current 12_000, rate 500/day → `ceil(8000/500)=16` days), zero-remaining → 0 days, rate 0 → insufficient_data, huge remaining (required 1_000_000, rate 10) → may_never, missing required → insufficient_data. Run `pytest tests/test_projection.py` — FAIL; implement `projection.py`; PASS.
- [ ] **Step 2:** Wire into `analysis.py` for primary metrics only (after the sample-size block, ~line 209-242), guarded so ratio/funnel rejection paths are untouched. Extend an existing endpoint test in `tests/test_api.py` to send `exposure_rate_per_day` and assert the `projection` block appears (and is absent when rate omitted — back-compat). Dispatch **python-qa** — green.
- [ ] **Step 3 (Elixir):** In `AnalysisWorker`, compute the rate with one Ecto count over assignments and put `"exposure_rate_per_day"` into the request config. In `ExperimentController.index`, join/preload each experiment's latest analysis and surface the primary metric's projection as `days_to_significance` (nil when absent). Extend the existing index controller test to assert the field exists (nil OK) and worker test to assert the config key is sent. Dispatch **elixir-qa** — green.
- [ ] **Step 4 (dashboard):** Add `projection`/`days_to_significance` to types. Detail page: under SignificanceCard, when the primary metric result has a projection and experiment is running, render "⏱ ~N days until significance at current traffic" or the may-never sentence (`text-sm text-gray-600`). List page: new column rendering the same strings compactly ("~16d", "may never", "—"). `npx vitest run` + build green.
- [ ] **Step 5:** Commit (explicit paths): `Roadmap #4: days-to-significance projection (engine + API + dashboard)` (body: 365-day cap → may_never; 7-day exposure window; product calls).

### Task 5: Roadmap #5 — Pre-launch power calculator wizard step

**Files:**
- Create: `apps/experiment_hub_web/lib/experiment_hub_web/controllers/power_estimate_controller.ex`; Test: `.../controllers/power_estimate_controller_test.exs`
- Modify: `router.ex` (`post "/power-estimate", PowerEstimateController, :create` in authenticated scope)
- Modify: `dashboard/src/pages/CreateExperimentPage.tsx` (new optional wizard step "Power" between Traffic and Settings)
- Create: `dashboard/src/components/experiments/PowerCalculatorStep.tsx`

**Interfaces:**
- Produces: `POST /api/v1/power-estimate` body `{baseline_rate: 0.05, mde: 0.10, significance_level: 0.05, power: 0.8, num_variants: 2}` → `{ "data": { "sample_size_per_variant": N, "total_sample_size": M, "estimated_days": D | null } }`. Thin proxy: Req.post to `{stat_engine_url}/stats/v1/power` with the `X-Internal-Key` header, exactly mirroring `AnalysisWorker`'s client config (read `analysis_worker.ex:81-84,200-202` first; also read `statistical_engine/src/api/routes/power.py` for the exact request field names — do NOT guess them). `estimated_days` = ceil(total_sample_size ÷ tenant assignments-per-day over the last 7 days); null when the tenant has no recent traffic. 502 with a friendly error when the engine is down.

- [ ] **Step 1 (TDD, Elixir):** Controller test using Bypass or a Req test adapter (follow however existing tests stub the stat engine — check `analysis_worker` tests; if none, use `Req.Test` plug stubbing which is the Req-idiomatic way). Cases: happy path returns per-variant + total + estimated_days derived from seeded assignments; no-traffic tenant → `estimated_days: null`; engine 500 → 502. FAIL → implement → PASS. **elixir-qa** green.
- [ ] **Step 2 (frontend-design pass first):** Sketch the step to match the wizard's existing visual language before coding (read the current step components in `CreateExperimentPage.tsx`). `PowerCalculatorStep.tsx`: inputs — baseline conversion rate (%), minimum detectable effect (relative %), desired power (80/90 radio); num_variants comes from the wizard's variants state. "Calculate" button → TanStack `useMutation` to the endpoint → result card: "You need **N users per variant** (M total). At your current traffic that's **~D days**." (traffic sentence omitted when null). Marked "Optional — estimates only, doesn't affect your experiment". Step is skippable via the normal Next button.
- [ ] **Step 3:** Wire into the wizard step array + step indicator. Add an RTL test `dashboard/tests/pages/powerStep.test.tsx` mocking the api module: fill inputs, click Calculate, assert the result sentence renders. Vitest + build green (**dashboard-qa**).
- [ ] **Step 4:** Commit: `Roadmap #5: pre-launch power calculator wizard step` (body: proxies existing /stats/v1/power; runtime from tenant 7-day assignment rate).

### Task 6: Roadmap #6 — Cohort chips + descriptive-only label

**Files:**
- Modify: `dashboard/src/components/experiments/SegmentBreakdownCard.tsx`
- Test: `dashboard/tests/components/segmentBreakdown.test.tsx`

- [ ] **Step 1:** Failing RTL test: renders chips Device / Country / New vs returning / Custom; clicking "Country" fires the segments query with `attribute=country`; the string "descriptive only — no significance claims" is visible; NO p-value text anywhere in the card.
- [ ] **Step 2:** Replace the free-text-first UI: chip row (`rounded-full border px-3 py-1 text-sm`, active chip `bg-indigo-600 text-white`) mapping Device→`device`, Country→`country`, New vs returning→`new_vs_returning`; a "Custom…" chip reveals the existing text input (keep the datalist). Keep the exact same query/API call (`?attribute=`). Add a permanent muted badge on the card header: "descriptive only — no significance claims" (`text-xs text-gray-500 border rounded-full px-2 py-0.5`). Do NOT add per-segment p-values or significance styling.
- [ ] **Step 3:** Vitest green; commit both files: `Roadmap #6: pre-canned cohort chips + explicit descriptive-only labeling` (body: chip keys device/country/new_vs_returning are the assignment-context conventions; custom input kept).

### Task 7: Roadmap #7 — Shareable readout link

**Files:**
- Create: migration `apps/experiment_hub/priv/repo/migrations/<ts>_create_shared_readouts.exs`, schema `apps/experiment_hub/lib/experiment_hub/experiments/shared_readout.ex`, context functions (in the module where experiment context functions live — follow the codebase's context layout)
- Create: `apps/experiment_hub_web/lib/experiment_hub_web/controllers/share_controller.ex`; Test: `.../controllers/share_controller_test.exs`
- Modify: `router.ex` — authenticated: `post "/experiments/:experiment_id/share-readout", ShareController, :create`; public (in the bare `:api` scope alongside /health): `get "/share/readout/:token", ShareController, :show`
- Modify: `dashboard/src/components/experiments/ExportMenu.tsx`

**Interfaces:**
- `POST .../share-readout` body `{html: string}` (client-generated via `buildReadoutHtml`; reject > 2_000_000 bytes with 422) → stores row (tenant_id, experiment_id, html) → `{ "data": { "url": "<endpoint-base>/share/readout/<token>" } }` where token = `Phoenix.Token.sign(ExperimentHubWeb.Endpoint, "shared-readout", readout_id)`.
- `GET /share/readout/:token`: `Phoenix.Token.verify(..., max_age: 30 * 24 * 3600)`; valid → 200 `text/html` with the stored HTML (+`X-Robots-Tag: noindex`, CSP `default-src 'none'; style-src 'unsafe-inline'`); invalid/expired/missing row → 404 JSON. Read-only; no auth (the signed unguessable token IS the capability). Follow the RLS idiom of recent migrations (see 20260401000023) — the public read must still work, so either query with the app's privileged mode used by other system reads or scope RLS accordingly; check how migrations set policies before writing.

- [ ] **Step 1 (TDD):** Controller tests: create→returns url containing a token; GET with that token serves the html with text/html; tampered token → 404; expired token (sign with `signed_at: System.system_time(:second) - 31*24*3600`) → 404; >2MB html → 422; cross-tenant create on someone else's experiment → 404.
- [ ] **Step 2:** Migration (uuid pk, tenant_id, experiment_id FKs, `html :text`, timestamps) + schema + controller + routes. FAIL→implement→PASS. **elixir-qa** green.
- [ ] **Step 3:** ExportMenu: add "Copy share link" item — builds html via existing `buildReadoutHtml(experiment, results)`, POSTs, `navigator.clipboard.writeText(data.url)`, flips the label to "Link copied ✓" for 2s; disabled (with title tooltip) when `results` is undefined. Vitest/build green.
- [ ] **Step 4:** Commit: `Roadmap #7: shareable read-only readout links (Phoenix.Token, 30-day expiry)` (body: stores client-generated HTML server-side; 2MB cap; CSP+noindex on the public route).

### Task 8: Roadmap #8 — Launch checklist gate

**Files:**
- Create: `dashboard/src/components/experiments/LaunchChecklistModal.tsx`, `dashboard/src/lib/launchChecklist.ts`
- Modify: `dashboard/src/pages/ExperimentDetailPage.tsx` (Start button opens the modal instead of firing immediately)
- Test: `dashboard/tests/lib/launchChecklist.test.ts`

**Interfaces:**
- `evaluateChecklist(experiment, timeline?: TimelineResponse): ChecklistItem[]` where `ChecklistItem = { key: "primary_metric" | "allocation" | "exposures"; label: string; status: "pass" | "fail" | "unknown"; detail: string }`. Checks: (a) a primary-role metric is attached; (b) variant `traffic_allocation`s sum to exactly 10000 bps; (c) exposure events observed recently — from the Task-3 timeline query's `daily_exposures` (an entry dated today/yesterday → pass; endpoint data unavailable → `unknown`, rendered as "couldn't verify", never blocking on its own).
- Modal: renders items as a checklist (✓ green / ✗ red / ? gray). All pass → primary button "Start experiment". Any fail → primary button disabled, secondary "Start anyway" which swaps to an explicit confirm ("Start with N unmet checks?") before firing the existing `startAction.mutate(id)`. Client-side only — no API changes.

- [ ] **Step 1:** Failing unit tests for `evaluateChecklist` (each check pass/fail/unknown, allocation 9000→fail, no timeline data→unknown). Implement. PASS.
- [ ] **Step 2:** Modal + wiring; keep the Start flow otherwise identical (pause/resume untouched). RTL test: with a fail item, "Start experiment" disabled and "Start anyway"→confirm→mutate called. Vitest/build green.
- [ ] **Step 3:** Commit: `Roadmap #8: pre-start launch checklist with explicit override` (body: exposure check is advisory-only when undetectable; schedule-sanity folded into allocation+metric checks as the detectable subset).

### Task 9: Roadmap #9 — Error boundary + full state coverage

**Files:**
- Create: `dashboard/src/components/ui/RouteErrorBoundary.tsx`, `dashboard/src/components/ui/QueryStates.tsx`
- Modify: `dashboard/src/App.tsx`; every page under `dashboard/src/pages/` that renders query data
- Test: `dashboard/tests/components/errorBoundary.test.tsx`

**Interfaces:**
- `RouteErrorBoundary`: class component (componentDidCatch), props `{children}`; renders a centered card — "Something went wrong on this page", the error message in a `<details>`, a "Try again" button that resets boundary state, and a "Go to dashboard" link. Mounted in `App.tsx` wrapping the routed content, keyed by `location.pathname` so navigation auto-recovers.
- `QueryStates.tsx` exports `LoadingState` (spinner + label, `aria-busy`), `ErrorState({error, onRetry})` (message + retry calling query `refetch`), `EmptyState({title, hint, cta?})` — all matching existing Tailwind idiom.

- [ ] **Step 1:** RTL test: a child that throws renders the fallback; clicking "Try again" after fixing the throw re-renders children. FAIL→implement→PASS.
- [ ] **Step 2:** Sweep every page (`Dashboard`, `ExperimentList`, `ExperimentDetail`, `CreateExperiment`, `Flags`, `Metrics`, `AuditLogs`, `Settings`, `ExperimentTimelinePage`): replace ad-hoc `isLoading`/`error` divs with the shared components; add missing empty states (each list page gets one with a CTA). Keep diffs surgical — states only, no refactors.
- [ ] **Step 3:** Vitest + build green (**dashboard-qa**). Commit (explicit file list): `Roadmap #9: route error boundary + consistent loading/empty/error states`.

### Task 10: Roadmap #10 — Responsive layout

**Files:**
- Modify: `dashboard/src/pages/Layout.tsx`; chart-container components as needed (`ExperimentResultsCharts`, timeline page)

- [ ] **Step 1:** Layout rebuild: desktop sidebar collapsible — toggle button collapses `w-64` → `w-16` icon-only (nav labels hidden, `title` attrs for icons), state persisted in `localStorage("sidebar-collapsed")`. Mobile (`< md`): sidebar hidden off-canvas; hamburger button in a top bar; overlay drawer (`fixed inset-y-0 left-0 z-40` + backdrop) that closes on nav click and Escape. Content area becomes `min-w-0 flex-1`.
- [ ] **Step 2:** Breakpoint pass: page-level grids get `grid-cols-1 md:grid-cols-N`; tables get `overflow-x-auto` wrappers; Recharts containers use `ResponsiveContainer` with a `min-w-0` parent (Recharts overflows flex parents without it).
- [ ] **Step 3:** Manual check via `npm run build` + vitest; verify no horizontal scroll at 375px width using existing Playwright setup ONLY if trivially available, else skip e2e here. Commit: `Roadmap #10: collapsible sidebar + responsive breakpoint pass`.

### Task 11: Roadmap #11 — Accessibility pass

**Files:**
- Modify: results table component(s) (`VariantTable`, `StatisticalSummary`), `CreateExperimentPage.tsx`, chart components, `Layout.tsx` nav, global focus styles (index.css)

- [ ] **Step 1:** Results tables: real `<table>/<thead>/<th scope="col">` semantics, `<caption class="sr-only">`, numeric cells right-aligned with `tabular-nums`. Charts: wrapping `<figure role="img" aria-label="...">` + `sr-only` text summary of the headline numbers.
- [ ] **Step 2:** Focus: add a visible `focus-visible:ring-2 focus-visible:ring-indigo-500` treatment to buttons/links/chips/inputs (via a shared class or index.css layer); skip-to-content link as first element in Layout; `aria-current="page"` on active nav.
- [ ] **Step 3:** Wizard keyboard nav: step list gets `aria-current="step"`; on step change move focus to the step heading (`ref` + `tabIndex={-1}` + `.focus()`); Enter in inputs advances via the existing Next handler; Back/Next reachable in tab order; every input gets an associated `<label htmlFor>`.
- [ ] **Step 4:** RTL smoke test asserting table semantics + aria-current. Vitest/build green. Commit: `Roadmap #11: accessibility pass (table semantics, focus states, wizard keyboard nav, chart alt text)`.

### Task 12: Roadmap #12 — Inline stats education

**Files:**
- Create: `dashboard/src/components/ui/InfoTip.tsx`, `dashboard/src/lib/statsGlossary.ts`
- Modify: `SignificanceCard`/`StatisticalSummary`, `BayesianResults`, `GuardrailBreachAlert` (or wherever those labels render — locate them first)
- Test: `dashboard/tests/components/infoTip.test.tsx`

**Interfaces:**
- `statsGlossary.ts`: `GLOSSARY: Record<"p_value" | "credible_interval" | "power" | "guardrail", { term: string; definition: string }>` — plain-English, 1–2 sentence definitions (p-value: "the probability of seeing a difference this large if the variants truly performed the same — lower means stronger evidence"; credible interval: "the range the true effect falls in with 95% probability, given the data"; power: "the chance this experiment would detect a real effect of the target size — 80%+ is the convention"; guardrail: "a metric that must not regress; a breach blocks shipping regardless of the primary result").
- `InfoTip`: `{term: keyof typeof GLOSSARY}` — an ⓘ `<button>` (aria-label "What is {term}?") toggling a positioned popover `role="tooltip"` linked via `aria-describedby`, shown on hover/focus/click, dismissed on Escape/blur. First-encounter behavior: the first time a given term's tip is rendered in the session (`localStorage("stat-tip-seen:{term}")` unset) the icon gets a subtle pulse (`animate-pulse text-indigo-500`) until first opened, then marked seen.
- "How to read this" link on the results card: toggles a collapsible panel listing all four definitions.

- [ ] **Step 1:** RTL test: tip opens on click with definition text, `aria-describedby` wired, Escape closes, seen-flag written. FAIL→implement→PASS.
- [ ] **Step 2:** Place tips beside the p-value, credible-interval, power, and guardrail labels; add the "How to read this" collapsible on the results card. Vitest/build green (**dashboard-qa**).
- [ ] **Step 3:** Commit: `Roadmap #12: first-encounter stats tooltips + how-to-read panel`.

### Task 13: Final verification + docs + push

- [ ] **Step 1:** Run **/qa-all** (all four subsystems must be green; fix and re-run until they are).
- [ ] **Step 2:** Run **/run-stack** then **/e2e** (`scripts/demo-e2e.ps1` lifecycle) — must pass.
- [ ] **Step 3:** Update `docs/ui-ux-roadmap.md`: change `Status: planned` to shipped; mark each of the 12 items with `✅ Shipped (2026-08-22)` and a one-line note of what was built.
- [ ] **Step 4:** Commit doc: `Roadmap: mark all 12 items shipped`. Push: `git push origin main`. NO tags.
