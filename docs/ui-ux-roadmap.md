# ExperimentHub UI/UX Improvement Roadmap (post-v1.0)

Status: **shipped — all 12 items landed on main, 2026-08-22** · Baseline: v1.0 (August 2026) · Audience: product managers and the dashboard team

Implementation plan and per-item commits: `docs/superpowers/plans/2026-08-22-ui-ux-roadmap.md`; commits are prefixed `Roadmap #N:`.

This roadmap is grounded in two inputs: a code-level survey of the dashboard
(`dashboard/src/`) and the UX patterns the experimentation industry has
converged on (Statsig, Eppo, GrowthBook, Optimizely, LaunchDarkly, Amplitude).
Items are ordered by how much they improve a PM's daily decision loop, not by
engineering convenience.

## Where v1.0 stands

What a PM can already do today:

- Run the full lifecycle: create (4-step wizard) → start → monitor → conclude,
  with decision + rationale captured (`CreateExperimentPage`, `ExperimentDetailPage`).
- Read results two ways: frequentist (`StatisticalSummary`) and Bayesian
  (`BayesianResults`), backed by real per-variant counts from the new
  `Metrics.AnalysisData` path.
- Slice results by any assignment-time attribute (`SegmentBreakdownCard` +
  `GET /api/v1/experiments/:id/segments`), deliberately without per-segment
  significance testing to avoid multiple-comparison false positives.
- Export a self-contained HTML readout, CSV, or JSON (`ExportMenu`, `lib/readout.ts`).
- Watch guardrails (`GuardrailBreachAlert`), audit activity, and manage flags,
  metrics, users, and API keys.

Known platform-level gaps at v1.0: no mobile layout (`Layout.tsx` has a fixed
`w-64` sidebar and no breakpoints), ~6 ARIA attributes across the whole app, no
React error boundary, and hardcoded UI strings.

## Tier 1 — Decision confidence (Now)

The theme: a PM should be able to make a ship/no-ship call without a
statistician in the room, and trust that the platform will flag an invalid
experiment before they decide on bad data.

1. **Plain-language decision panel.** Map the primary-metric outcome plus
   guardrail status to a canned recommendation — "Ship variant B",
   "Keep collecting", "Do not ship (guardrail breached)" — rendered above the
   raw stats on `ExperimentDetailPage` and in the exported readout.
   *Pattern:* Statsig's decision framework; Optimizely's one-click executive
   summary. *Build on:* `ConclusionSummary`, `StatisticalSummary`, `lib/readout.ts`.
   ✅ **Shipped 2026-08-22** — `deriveDecision` in `lib/readout.ts` maps results to four
   states (Ship / Do not ship / Keep collecting / No detectable effect); `DecisionPanel`
   above the stats and a banner at the top of the exported readout.

2. **Experiment health diagnostics (SRM).** Add a sample-ratio-mismatch
   chi-square check over assignment counts (already available via
   `Metrics.AnalysisData.variant_stats/2`) and surface a warning banner when
   observed traffic split deviates from the configured allocation. Alert, don't
   block. *Pattern:* Eppo's diagnostics panel, which pairs each warning with a
   plain-language fix suggestion.
   ✅ **Shipped 2026-08-22** — client-side chi-square (`lib/srm.ts`) over the per-variant
   counts already in the results; `SrmWarningBanner` warns at p < 0.001, dismissible per
   analysis run, never blocks.

3. **Restore the experiment timeline.** `ExperimentTimelinePage` was removed
   before v1.0; reinstate it as a lifecycle view — start/pause/resume/conclude
   markers over a cumulative-exposures chart, so "when did this start collecting
   and what happened mid-run" has an answer. *Pattern:* Eppo's timeline view;
   GrowthBook's experiment phases. *Build on:* `TimelineChart`,
   `ConversionOverTimeChart`, the audit log as the event source.
   ✅ **Shipped 2026-08-22** — `GET /api/v1/experiments/:id/timeline` (audit lifecycle +
   daily assignment counts) and the `/experiments/:id/timeline` route reusing
   `TimelineChart` plus a cumulative-exposures chart with lifecycle markers.

4. **Days-to-significance estimate.** For running experiments, project time to
   significance from current exposure rate and variance; show it on the detail
   page and the list view. *Pattern:* Amplitude's duration estimates.
   *Build on:* `statistical_engine/src/core/power.py` and `sequential.py`.
   ✅ **Shipped 2026-08-22** — engine `projection` block (from the existing sample-size
   math + an exposure rate Elixir sends), "~N days" on the detail page and a column on
   the list; >365 days reads "may never reach significance at current traffic".

## Tier 2 — Workflow speed (Next)

5. **Pre-launch power calculator in the wizard.** An interactive step in
   `CreateExperimentPage`: pick the metric, enter minimum detectable effect,
   see required sample size and estimated runtime from recent traffic. The math
   exists in `power.py`; only the UI is missing. *Pattern:* GrowthBook's power
   calculator with its "MDE over time" grid.
   ✅ **Shipped 2026-08-22** — optional "Power" wizard step backed by
   `POST /api/v1/power-estimate` (thin proxy over the existing `/stats/v1/power`);
   runtime estimate from the tenant's 7-day assignment rate.

6. **Pre-canned cohorts + multiple-comparison guardrail.** Replace the
   free-text attribute input in `SegmentBreakdownCard` with chips for the
   common cuts (device, country, new vs. returning) plus a custom option, and
   label the card with an explicit "descriptive only — no significance claims"
   note. *Pattern:* LaunchDarkly's cohort drilldowns and its visible
   multiple-comparison-correction control.
   ✅ **Shipped 2026-08-22** — Device / Country / New vs returning / Custom chips;
   permanent "descriptive only — no significance claims" badge; no per-segment p-values.

7. **Shareable readout link.** The readout is already a self-contained HTML
   file; add a signed read-only URL so a PM can drop a link in Slack instead of
   attaching a file. *Pattern:* Optimizely's no-account share link.
   ✅ **Shipped 2026-08-22** — "Copy share link" in `ExportMenu` stores the generated
   readout and returns `/share/readout/:token` (Phoenix.Token, 30-day expiry, read-only,
   noindex + strict CSP).

8. **Launch checklist.** A pre-start gate on the experiment: primary metric
   attached, traffic allocation sums to 100, exposure events observed in the
   last hour, schedule sane. *Pattern:* Statsig's setup checklist.
   ✅ **Shipped 2026-08-22** — `LaunchChecklistModal` gates Start on primary metric
   attached, allocations = 100 %, recent exposures (advisory when undetectable);
   "Start anyway" requires an explicit confirmation.

## Tier 3 — Platform quality (Later)

9. **Error boundaries and full state coverage.** One route-level React error
   boundary plus consistent loading/empty/error states on every page (today
   only 2 components handle `onError`; a failed API call can blank a page).
    ✅ **Shipped 2026-08-22** — `RouteErrorBoundary` keyed by route; shared
    `LoadingState` / `ErrorState` (with retry) / `EmptyState` across every page.
10. **Responsive layout.** Collapsible sidebar and breakpoint pass over
    `Layout.tsx` and the chart containers, so results are checkable from a phone.
    ✅ **Shipped 2026-08-22** — collapsible sidebar (persisted), off-canvas mobile
    drawer with Escape/backdrop close, responsive grids, scrollable tables, `min-w-0`
    chart containers.
11. **Accessibility pass.** Table semantics for results, focus states, chart
    text alternatives, keyboard navigation through the wizard.
    ✅ **Shipped 2026-08-22** — table captions/scopes, global focus-visible ring, skip
    link, `aria-current` nav/steps, wizard focus management + Enter-to-advance, chart
    `figure` alt text, dialog semantics on modals, keyboard-operable metric rows.
12. **Inline stats education.** Tooltips defining p-value, credible interval,
    power, and guardrail on first encounter; a "how to read this" link on the
    results card. Reduces the onboarding cliff for new PMs.
    ✅ **Shipped 2026-08-22** — `InfoTip` + `statsGlossary` (p-value, credible
    interval, power, guardrail) with a first-encounter pulse, and a "How to read this"
    panel on the results card.

## Why this is useful for a PM, concretely

| PM job | What changes |
|---|---|
| Decide faster | Decision panel (1) + days-to-significance (4) turn raw stats into a recommendation and an ETA. |
| Trust the numbers | SRM diagnostics (2) catch broken splits before a decision; MCC labeling (6) prevents false segment wins. |
| Plan before launch | Power calculator (5) + checklist (8) stop doomed experiments from launching at all. |
| Communicate | Shareable readout (7) + plain-language summary (1) make the readout the artifact PMs forward, not a screenshot. |
| Reconstruct history | Timeline (3) + audit log answer "what happened and when" in one view. |

## Sequencing note

Tier 1 items are independent of each other and of Tier 2/3; nothing here
requires schema changes beyond what v1.0 already shipped (the `context` map on
assignments is the substrate for cohorts, and `AnalysisData` already exposes
per-variant counts for SRM). The highest-leverage single item is the decision
panel: it reuses existing stats output and changes only presentation.
