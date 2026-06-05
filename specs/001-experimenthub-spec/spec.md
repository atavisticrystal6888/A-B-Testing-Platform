# Feature Specification: ExperimentHub — A/B Testing & Experimentation Platform

**Feature Branch**: `001-experimenthub-spec`
**Created**: 2026-03-31
**Status**: Draft
**Input**: ExperimentHub — a self-hosted, production-grade A/B Testing & Experimentation Platform enabling product teams to run A/B tests, multivariate tests, and feature rollouts with statistical rigor. Replaces expensive SaaS tools (LaunchDarkly, Optimizely, Statsig) for organizations needing data sovereignty, customization, and cost control.

## Product Vision

ExperimentHub is a self-hosted experimentation platform that enables product teams to run A/B tests, multivariate tests, and feature rollouts with statistical rigor. It provides:

- **Data sovereignty**: All experiment data stays within the organization's infrastructure.
- **Statistical rigor**: Every experiment conclusion is backed by valid statistical methods — no declaring winners without significance.
- **Cost control**: Eliminates per-seat or per-event SaaS pricing models.
- **Customization**: Full access to source code, statistical methodology, and data pipelines.

## Clarifications

### Session 2026-03-31

- Q: Which tenant isolation strategy should the spec mandate (schema-per-tenant, row-level security, or database-per-tenant)? → A: Row-level security (RLS) — single schema with `tenant_id` column and PostgreSQL RLS policies enforcing isolation.
- Q: Which hashing algorithm should be used for deterministic user-to-variant assignment? → A: MurmurHash3 — fastest option with excellent uniformity, widely available cross-platform.
- Q: What conflict resolution strategy for concurrent experiment modifications by multiple editors? → A: Optimistic locking — version column check on every write, HTTP 409 Conflict returned on stale updates.
- Q: How should the event collector handle Kafka unavailability? → A: Local disk-backed buffer queue with retry and exponential backoff; no events are lost.
- Q: Should API keys have automatic expiration or be permanent until revoked? → A: No automatic expiry by default — keys remain valid until manually revoked, with an optional configurable TTL per key.

### Session 2026-04-01 — Terminology, Anonymization, and Key/ID Resolution

- Q: Several terms are used inconsistently across artifacts — "mutual exclusion group" vs "ExperimentGroup", "user_id" referring to both experiment participants and dashboard users, "traffic allocation" expressed as percentages vs basis points. How should these be standardized? → A: A new **Terminology & Conventions** section is added to the spec establishing canonical names. `ExperimentGroup` is the entity name; "mutual exclusion group" is acceptable in prose. `user_id` in SDK-facing APIs refers to the external **participant**; internal docs use "participant" to disambiguate from dashboard `User`. Traffic allocation is basis points (0–10000) in API contracts; percentages in prose.
- Q: FR-072 says "anonymize all data" without specifying the anonymization method, scope, or impact on aggregated results. What does anonymization mean concretely? → A: FR-072 is expanded to specify: (1) scope: `assignments`, `experiment_events_raw`, `audit_logs`; (2) method: deterministic pseudonymization via `SHA-256(tenant_id || user_id || salt)` to preserve aggregate consistency; (3) aggregated results are NOT modified; (4) irreversible, single-transaction execution with background processing for large datasets.
- Q: The Event API requires `experiment_id` (UUID) but the Assignment API uses `experiment_key` (string). SDK developers must know how to resolve one to the other. Is this documented? → A: A new **experiment_key vs experiment_id Resolution Strategy** subsection is added under Terminology. The Assignment API is the entry point that returns both identifiers; SDKs cache the mapping; the Event API uses UUIDs for hot-path performance. The Event API intentionally does NOT accept `experiment_key`.

## Terminology & Conventions

The following terms are used precisely throughout this specification. All artifacts (contracts, data model, tasks) MUST use these terms consistently.

| Term | Definition | Disambiguation |
|------|------------|----------------|
| **experiment_key** | A human-readable, URL-safe string identifier for an experiment (e.g., `checkout-button-color`). Used in SDK-facing APIs (Assignment, Feature Flags). Max 100 chars. | NOT the same as `experiment_id`. |
| **experiment_id** | A system-generated UUID that uniquely identifies an experiment internally. Used in internal APIs (Event ingestion, Statistical engine, Management API paths). | Returned by the Assignment API alongside `experiment_key` so SDKs can cache and reuse it for event submission. |
| **participant_id** | The external identifier for an end-user participating in experiments (passed as `user_id` in Assignment and Event APIs). This is the application's user identifier, NOT an ExperimentHub dashboard user. Max 255 chars. | The field name `user_id` is retained in API contracts for SDK ergonomics, but specs and internal docs SHOULD use "participant" when referring to experiment subjects to avoid confusion with dashboard `User`. |
| **User** | A person who accesses the ExperimentHub dashboard. Has email, password, role. Belongs to a Tenant. Stored in `users` table. | NOT an experiment participant. |
| **Variant** | Any distinct treatment arm within an experiment, including the control. One variant per experiment MUST be designated `is_control: true`. | "Treatment" refers specifically to non-control variants. "Control" is the baseline variant. |
| **ExperimentGroup** | The canonical entity name for a mutual exclusion group (also called "experiment layer"). Contains experiments where a participant can be enrolled in at most one. | Specs may say "mutual exclusion group" in prose; the data model entity and API resource name is `ExperimentGroup` / `experiment-groups`. |
| **traffic_allocation** | The percentage of traffic directed to a variant, expressed as an integer in basis points (0–10000, where 10000 = 100%). | Management API uses basis points for precision. Spec prose uses percentages for readability. SDK docs MUST clarify the unit. |
| **MetricDefinition** | A reusable metric template (e.g., "checkout conversion rate"). Defines the event(s) to count and computation type. | Distinct from **ExperimentMetric**, which is the attachment of a MetricDefinition to a specific experiment with a role (primary/secondary/guardrail). |

### experiment_key vs experiment_id Resolution Strategy

The Assignment API accepts `experiment_key` (human-readable) and returns both `experiment_key` and `experiment_id` (UUID) in the response. The Event API requires `experiment_id` (UUID). This asymmetry is **intentional**:

1. **Assignment is the entry point**: Every SDK integration calls the Assignment API first to determine which variant a participant receives. The response includes `experiment_id`.
2. **SDKs cache the mapping**: After the first assignment call, the SDK caches the `experiment_key → experiment_id` mapping locally (TTL: 5 minutes, per Assumption 7).
3. **Events use UUIDs for performance**: The Event API processes 50K+ events/sec (NFR-002). UUID lookups on indexed columns are faster than string key lookups; eliminating a key→id resolution step on the hot path is critical.
4. **Fallback**: If an SDK sends events without a prior assignment call, it MUST first call `POST /v1/assign` or `POST /v1/assign/batch` to resolve the `experiment_key` to `experiment_id`. The Event API does NOT accept `experiment_key`.

This design is documented in SDK integration guides. The Assignment API response schema is the **single source of truth** for the key→id mapping.

---

## Target Personas

1. **Product Manager (Primary)** — Creates experiments, defines hypotheses, reviews results, makes ship/no-ship decisions.
2. **Data Analyst** — Configures metrics, reviews statistical methodology, validates results, creates custom reports.
3. **Software Engineer** — Integrates SDK into application code, checks experiment assignments, logs events.
4. **Engineering Manager** — Reviews experiment velocity, monitors system health, manages team permissions.
5. **Platform Admin** — Manages tenants, API keys, system configuration, monitors infrastructure.

---

## User Scenarios & Testing *(mandatory)*

### US1 — PM Creates an A/B Experiment (Priority: P1)

A Product Manager creates a new A/B experiment with a clear hypothesis, two or more variants, traffic allocation percentages, and a primary success metric. The experiment starts in draft state and can be launched when ready.

**Why this priority**: This is the entry point to the entire experimentation workflow. Without experiment creation, no other feature has value.

**Independent Test**: Can be fully tested by creating an experiment through the UI, verifying all fields persist correctly, and confirming the experiment appears in the experiment list in "draft" state.

**Acceptance Scenarios**:

1. **Given** a PM is logged into the dashboard, **When** they complete the experiment creation form with a hypothesis ("Green checkout button increases conversions by 5%"), two variants (control: blue, treatment: green), 50/50 traffic split, and select "checkout_conversion" as the primary metric, **Then** the experiment is saved in "draft" state and appears in the experiment list.
2. **Given** an experiment is in "draft" state, **When** the PM clicks "Launch Experiment", **Then** the experiment transitions to "running" state and begins accepting traffic assignments.
3. **Given** the PM is creating an experiment, **When** they set traffic allocation that does not sum to 100%, **Then** the system displays a validation error and prevents saving.
4. **Given** the PM is creating an experiment, **When** they do not specify a hypothesis or primary metric, **Then** the system displays a validation error requiring these mandatory fields.

---

### US2 — Engineer Integrates SDK and Gets Variant Assignments (Priority: P1)

A Software Engineer integrates the ExperimentHub SDK into application code. When a user visits the application, the SDK requests a variant assignment for that user and experiment. The assignment is deterministic — the same user always gets the same variant for the same experiment.

**Why this priority**: Assignment is the core mechanism that makes experimentation possible. Without deterministic assignment, experiments produce invalid results.

**Independent Test**: Can be tested by calling the assignment endpoint with the same user/experiment pair 100 times and verifying the same variant is returned every time.

**Acceptance Scenarios**:

1. **Given** an experiment is in "running" state with variants A (50%) and B (50%), **When** an engineer calls the assignment endpoint with user_id="user123" and experiment_key="checkout-button-color", **Then** the system returns a deterministic variant assignment (e.g., variant B).
2. **Given** the same user_id and experiment_key, **When** the assignment endpoint is called multiple times across different sessions, **Then** the same variant is returned every time.
3. **Given** an experiment is not in "running" state, **When** the assignment endpoint is called, **Then** the system returns the control variant (default fallback).
4. **Given** 100,000 unique user IDs assigned to a 50/50 experiment, **When** assignment distribution is analyzed, **Then** the split is within ±1% of the configured allocation (verified by chi-squared test, p > 0.05).
5. **Given** the assignment service is temporarily unavailable, **When** the SDK cannot reach the endpoint, **Then** the SDK returns the control variant (fail-open behavior) and logs a warning.

---

### US3 — Event Collector Receives and Persists Metric Events (Priority: P1)

The application sends conversion and metric events to ExperimentHub's event collector. Events are validated, deduplicated, and persisted for later analysis. Events can be sent individually or in batches.

**Why this priority**: Without event collection, experiments have no data to analyze. This completes the data ingestion side of the experimentation loop.

**Independent Test**: Can be tested by sending events to the collector endpoint and verifying they appear in the data store with correct attributes.

**Acceptance Scenarios**:

1. **Given** a user has been assigned to variant B of experiment "checkout-button-color", **When** the application sends a conversion event (event_type: "conversion", event_name: "checkout_completed", value: 1), **Then** the event is persisted with the correct experiment_id, variant, user_id, and timestamp.
2. **Given** the application sends a batch of 500 events in a single request, **When** the collector processes the batch, **Then** all 500 events are persisted and the response returns a success status with the count of accepted events.
3. **Given** the same event is sent twice with the same idempotency key, **When** the collector processes both, **Then** only one event is persisted (deduplication).
4. **Given** an event is sent with missing required fields (e.g., no user_id), **When** the collector validates it, **Then** the event is rejected with a descriptive error message, and valid events in the same batch are still processed.
5. **Given** the event collector is receiving high throughput, **When** events arrive faster than they can be persisted, **Then** the system applies backpressure gracefully without dropping events or crashing.

---

### US4 — Platform Computes Experiment Results with Statistical Significance (Priority: P1)

The platform continuously aggregates event data and computes experiment results. Statistical analysis includes confidence intervals, p-values, effect sizes, and a clear recommendation. Sequential analysis prevents the "peeking problem" from inflating false-positive rates.

**Why this priority**: Statistical computation transforms raw event data into actionable decisions. Without statistically valid results, experiments are meaningless.

**Independent Test**: Can be tested by ingesting a known dataset (e.g., 10,000 events per variant with known conversion rates) and verifying the computed p-value, confidence interval, and effect size match reference calculations within 0.1% margin.

**Acceptance Scenarios**:

1. **Given** experiment "checkout-button-color" has accumulated 5,000 events per variant with conversion rates of 10% (control) and 12% (treatment), **When** the statistical engine runs analysis, **Then** it returns a p-value, 95% confidence interval for the difference, and the observed effect size (+2 percentage points).
2. **Given** an experiment has not yet reached the calculated minimum sample size, **When** results are viewed, **Then** the system displays results with a warning: "Insufficient sample size — results are preliminary" and does not declare a winner.
3. **Given** an experiment with 3+ variants, **When** analysis runs, **Then** multiple comparison corrections are applied automatically and the adjusted p-values are reported.
4. **Given** a PM views results of a running experiment multiple times (peeking), **When** sequential analysis is applied, **Then** the alpha spending function controls the overall false-positive rate at the configured level (default 5%).
5. **Given** both frequentist and Bayesian analysis are enabled for an experiment, **When** results are computed, **Then** both p-values and probability-to-be-best are displayed side by side.

---

### US5 — PM Views Experiment Dashboard with Results (Priority: P1)

A Product Manager views a dashboard showing all experiments, their status, and detailed results for any selected experiment. The results view shows variant performance comparison, confidence intervals, cumulative conversion over time, and a clear recommendation.

**Why this priority**: The dashboard is the decision-making interface. PMs need clear, visual results to make ship/no-ship decisions.

**Independent Test**: Can be tested by loading the dashboard with at least one running experiment that has accumulated data, verifying all result components render correctly.

**Acceptance Scenarios**:

1. **Given** the PM navigates to the experiments list, **When** the page loads, **Then** all experiments are displayed with their name, status (draft/running/paused/concluded), creation date, and variant count.
2. **Given** the PM clicks on a running experiment, **When** the detail view loads, **Then** it shows: variant performance table (conversions, conversion rate, sample size per variant), confidence interval chart, cumulative conversion-over-time chart, and statistical significance status.
3. **Given** experiment results show a statistically significant winner, **When** the PM views the detail page, **Then** the winning variant is highlighted with a clear recommendation (e.g., "Treatment B is the winner with 95% confidence").
4. **Given** an experiment is running and new events arrive, **When** the PM is viewing the experiment detail page, **Then** the results update in near-real-time (within 2 minutes) without requiring a manual page refresh.
5. **Given** the PM is on the dashboard, **When** they filter experiments by status (e.g., "running only"), **Then** only experiments matching the filter are displayed.

---

### US6 — PM Stops Experiment and Records Decision (Priority: P1)

A Product Manager stops a running experiment and records the decision outcome: ship the winning variant, revert to control, or note that results were inconclusive. The decision and rationale are permanently recorded in the audit trail.

**Why this priority**: Completing the experiment lifecycle is essential. The platform must capture the decision to close the feedback loop.

**Independent Test**: Can be tested by concluding a running experiment, selecting an outcome, and verifying the experiment transitions to "concluded" state with the decision recorded.

**Acceptance Scenarios**:

1. **Given** an experiment is in "running" state, **When** the PM clicks "Stop Experiment" and selects outcome "Ship Variant B" with rationale "12% conversion vs 10% control, statistically significant", **Then** the experiment transitions to "concluded" state with the decision recorded.
2. **Given** an experiment is concluded, **When** anyone views the experiment detail, **Then** the conclusion decision, rationale, who made the decision, and when are all visible.
3. **Given** an experiment is in "concluded" state, **When** any user attempts to restart it, **Then** the system prevents restarting and displays a message that concluded experiments cannot be restarted (a new experiment must be created).
4. **Given** an experiment is in "running" state, **When** the PM clicks "Pause Experiment", **Then** the experiment transitions to "paused" state — no new assignments are made, but existing events continue to be collected.

---

### US7 — PM Creates Multivariate Test (Priority: P2)

A Product Manager creates a multivariate experiment with more than two variants (A/B/C/D or more) with custom traffic allocation splits. The statistical engine automatically applies multiple comparison corrections.

**Why this priority**: Multivariate tests enable richer experimentation beyond simple A/B, but are not required for the core MVP.

**Independent Test**: Can be tested by creating a 4-variant experiment, verifying assignments distribute correctly across all variants, and confirming multiple comparison corrections are applied in results.

**Acceptance Scenarios**:

1. **Given** a PM creates an experiment with 4 variants (A: 25%, B: 25%, C: 25%, D: 25%), **When** the experiment is launched, **Then** user assignments distribute across all 4 variants within ±1% of configured allocation.
2. **Given** a multivariate experiment with 4 variants has accumulated sufficient data, **When** statistical analysis runs, **Then** pairwise comparisons are performed with Bonferroni or Holm-Šidák correction applied, and adjusted p-values are reported for each pair.
3. **Given** a PM creates an experiment, **When** they configure uneven traffic splits (A: 50%, B: 20%, C: 20%, D: 10%), **Then** the system validates that splits sum to 100% and assignments respect the configured ratios.

---

### US8 — PM Configures Experiment Targeting Rules (Priority: P2)

A Product Manager defines targeting rules to control which users are eligible for an experiment. Rules can be based on user properties (country, device type, plan tier), custom attributes, or percentage-based rollout.

**Why this priority**: Targeting enables running experiments on specific user segments, which is critical for localized experiments and reducing blast radius.

**Independent Test**: Can be tested by creating a targeting rule (e.g., "country = US"), requesting assignment for a user matching the rule and a user not matching it, and verifying only the eligible user gets assigned.

**Acceptance Scenarios**:

1. **Given** an experiment has a targeting rule "country = US", **When** a user with country="US" requests assignment, **Then** they receive a variant assignment.
2. **Given** the same experiment, **When** a user with country="GB" requests assignment, **Then** they receive the control/default experience (not enrolled in the experiment).
3. **Given** a PM creates a compound targeting rule (country="US" AND device="mobile"), **When** a user with country="US" and device="desktop" requests assignment, **Then** they are not enrolled.
4. **Given** a PM modifies targeting rules on a running experiment, **When** existing users who no longer match the rules request assignment, **Then** they continue receiving their previously assigned variant (no flip-flopping). New users who don't match are not enrolled.

---

### US9 — Analyst Configures Guardrail Metrics (Priority: P2)

A Data Analyst configures guardrail metrics for an experiment. If a guardrail metric (e.g., error rate, page load time) degrades beyond a configured threshold, the experiment is automatically paused to prevent harm.

**Why this priority**: Guardrails prevent experiments from degrading user experience. This is important for production safety but not required for basic experimentation.

**Independent Test**: Can be tested by configuring a guardrail metric with a threshold, ingesting events that breach the threshold, and verifying the experiment auto-pauses.

**Acceptance Scenarios**:

1. **Given** an analyst configures guardrail "error_rate" with threshold "> 5%" on an experiment, **When** the treatment variant's error rate exceeds 5%, **Then** the experiment is automatically paused and the team is notified.
2. **Given** a guardrail triggers, **When** the PM views the experiment, **Then** the pause reason clearly states which guardrail was breached and by how much.
3. **Given** multiple guardrail metrics are configured, **When** any single guardrail is breached, **Then** the experiment pauses immediately (fail-fast behavior).

---

### US10 — PM Schedules Experiment Start/End Dates (Priority: P2)

A Product Manager schedules an experiment to start and/or end at specific dates and times. The platform automatically transitions experiments through their lifecycle on schedule.

**Why this priority**: Scheduling enables planned experiment campaigns and prevents experiments from running indefinitely, but is not needed for manual experimentation.

**Independent Test**: Can be tested by scheduling an experiment to start 1 minute in the future, verifying it transitions to "running" state automatically.

**Acceptance Scenarios**:

1. **Given** a PM creates an experiment with start_date="2026-04-15 09:00 UTC", **When** the current time reaches the start date, **Then** the experiment automatically transitions from "draft" to "running".
2. **Given** a PM configures end_date="2026-05-15 09:00 UTC" on a running experiment, **When** the current time reaches the end date, **Then** the experiment automatically transitions to "concluded" with reason "scheduled_end".
3. **Given** a PM sets both start and end dates, **When** viewing the experiment, **Then** the scheduled timeline is visible.

---

### US11 — Analyst Views Bayesian Results Alongside Frequentist (Priority: P2)

A Data Analyst views experiment results that show both frequentist analysis (p-values, confidence intervals) and Bayesian analysis (probability-to-be-best, credible intervals, expected loss) side by side for a comprehensive statistical picture.

**Why this priority**: Dual statistical methodology provides richer decision-making context, especially for smaller sample sizes where Bayesian methods excel.

**Independent Test**: Can be tested by running analysis on an experiment with sufficient data and verifying both frequentist and Bayesian result sections render with correct values.

**Acceptance Scenarios**:

1. **Given** an experiment has sufficient data, **When** the analyst views results, **Then** the frequentist section shows p-value, 95% confidence interval, and effect size, while the Bayesian section shows probability-to-be-best, 95% credible interval, and expected loss.
2. **Given** an experiment with small sample size, **When** frequentist results show "not significant" but Bayesian shows 80% probability-to-be-best, **Then** both results are displayed without conflict, allowing the analyst to interpret both signals.

---

### US12 — PM Adds Experiment to Mutual Exclusion Group (Priority: P3)

A Product Manager adds an experiment to a mutual exclusion group, ensuring that users participating in one experiment within the group cannot be enrolled in another experiment in the same group. This prevents interaction effects between related experiments.

**Why this priority**: Mutual exclusion prevents statistical contamination between experiments, but is only needed when multiple concurrent experiments could interact.

**Independent Test**: Can be tested by creating two experiments in the same exclusion group, assigning a user to one, and verifying they cannot be assigned to the other.

**Acceptance Scenarios**:

1. **Given** experiments A and B are in mutual exclusion group "checkout-tests", **When** user "user123" is assigned to experiment A, **Then** requesting assignment for experiment B returns "not enrolled" for the same user.
2. **Given** a mutual exclusion group with 3 experiments sharing a combined traffic allocation of 100%, **When** assignments are distributed, **Then** each user is in at most one experiment and the overall allocation respects configured splits.
3. **Given** experiment A in a mutual exclusion group concludes, **When** the traffic previously reserved for A is released, **Then** remaining experiments can absorb the freed traffic if configured to do so.

---

### US13 — Manager Reviews Experiment History with Audit Trail (Priority: P3)

An Engineering Manager reviews the complete history of changes to any experiment — who created it, when it was launched, any modifications to targeting or traffic allocation, when it was paused or concluded, and the decision rationale.

**Why this priority**: Audit trail supports accountability and compliance, but is not needed for basic experimentation.

**Independent Test**: Can be tested by performing several actions on an experiment (create, modify targeting, launch, pause, conclude) and verifying every action appears in the audit log with the correct actor, timestamp, and details.

**Acceptance Scenarios**:

1. **Given** an experiment has undergone multiple state changes and configuration edits, **When** a manager views the audit trail, **Then** every change is listed chronologically with: who made the change, what changed (before/after values), when, and why (if a reason was provided).
2. **Given** a manager filters the audit trail by date range and action type, **When** the filter is applied, **Then** only matching entries are displayed.
3. **Given** audit log entries exist, **When** anyone attempts to modify or delete an audit entry, **Then** the system prevents modification (append-only).

---

### US14 — Admin Manages Tenants, API Keys, and Permissions (Priority: P3)

A Platform Admin creates and manages tenants (organizations), generates API keys for each tenant, and assigns role-based permissions (viewer, editor, admin) to users within a tenant.

**Why this priority**: Multi-tenancy and access control are essential for production use but can be added after core experimentation works.

**Independent Test**: Can be tested by creating a tenant, generating an API key, creating users with different roles, and verifying each role has the correct access level.

**Acceptance Scenarios**:

1. **Given** a platform admin, **When** they create a new tenant with name "Acme Corp", **Then** the tenant is created with a unique identifier and is isolated from all other tenants.
2. **Given** a tenant exists, **When** the admin generates an API key for that tenant, **Then** a unique, cryptographically secure API key is returned and can be used to authenticate requests scoped to that tenant.
3. **Given** a user with "viewer" role in a tenant, **When** they attempt to create or modify an experiment, **Then** the system denies the action with a 403 Forbidden response.
4. **Given** a user with "editor" role, **When** they create and launch an experiment, **Then** the action succeeds, but they cannot manage API keys or users (admin-only actions).
5. **Given** tenant A and tenant B exist, **When** a user authenticated to tenant A requests experiments, **Then** only tenant A's experiments are returned; tenant B's data is never visible.

---

### US15 — Analyst Exports Experiment Results (Priority: P3)

A Data Analyst exports experiment results in CSV, JSON, or Excel format for further analysis in external tools like Power BI, Excel, or custom scripts.

**Why this priority**: Export enables integration with existing analytics workflows but is not needed for in-platform analysis.

**Independent Test**: Can be tested by exporting a concluded experiment's results in each format and verifying the exported file contains complete, accurate data.

**Acceptance Scenarios**:

1. **Given** an experiment with computed results, **When** the analyst clicks "Export" and selects CSV, **Then** a CSV file is downloaded with columns: variant, sample_size, conversions, conversion_rate, confidence_interval_lower, confidence_interval_upper, p_value.
2. **Given** the same experiment, **When** the analyst exports as JSON, **Then** a JSON file is downloaded with the full analysis including both frequentist and Bayesian results.
3. **Given** the same experiment, **When** the analyst exports as Excel, **Then** an Excel workbook is downloaded with separate sheets for summary, per-variant details, and daily time series.

---

### US16 — Engineer Uses SDK for Feature Flags (Priority: P4)

A Software Engineer uses the same ExperimentHub SDK to evaluate simple on/off feature flags without needing to set up a full experiment. Feature flags share the same assignment infrastructure.

**Why this priority**: Feature flags are a natural extension of the assignment engine and reduce the need for a separate feature flag service, but are not core experimentation.

**Independent Test**: Can be tested by creating a feature flag, evaluating it for different users, and verifying the correct on/off state.

**Acceptance Scenarios**:

1. **Given** a feature flag "new-checkout-flow" is created with default state "off", **When** an engineer evaluates the flag for any user, **Then** the result is "off".
2. **Given** the feature flag is enabled for 100% of users, **When** any user evaluates the flag, **Then** the result is "on".
3. **Given** the feature flag has targeting rules (e.g., enabled for "beta_testers" segment), **When** a beta tester user evaluates the flag, **Then** the result is "on"; a non-beta-tester gets "off".

---

### US17 — PM Creates Percentage-Based Rollout (Priority: P4)

A Product Manager creates a percentage-based feature rollout, gradually increasing the percentage of users who see the new feature: 5% → 25% → 50% → 100%.

**Why this priority**: Gradual rollout is a key use case for feature flags but dependent on the base feature flag functionality.

**Independent Test**: Can be tested by creating a rollout at 5%, verifying approximately 5% of users get the feature, then ramping to 50% and verifying the new distribution.

**Acceptance Scenarios**:

1. **Given** a rollout is created at 5%, **When** 10,000 users are evaluated, **Then** approximately 500 (±50) users receive the "on" variant.
2. **Given** the rollout is increased from 5% to 25%, **When** users that previously received "on" are re-evaluated, **Then** they still receive "on" (monotonic rollout — users are not removed).
3. **Given** the rollout is at 100%, **When** any user evaluates the flag, **Then** all users receive "on".

---

### US18 — Engineer Gets Feature Flag with Targeting Rules (Priority: P4)

A Software Engineer evaluates a feature flag with targeting rules that combine user properties and segments to determine eligibility.

**Why this priority**: Targeting for feature flags extends the targeting rules engine already built for experiments.

**Independent Test**: Can be tested by creating a flag with targeting rules and evaluating for users matching/not matching the rules.

**Acceptance Scenarios**:

1. **Given** a feature flag with rule "plan = enterprise AND country = US", **When** a user with plan="enterprise" and country="US" evaluates the flag, **Then** the result is "on".
2. **Given** the same flag, **When** a user with plan="free" evaluates the flag, **Then** the result is "off" (does not match targeting).

---

### US19 — Analyst Views Platform-Wide Dashboard (Priority: P5)

A Data Analyst views a platform-wide analytics dashboard showing: active experiments count, experiments concluded this month, average experiment duration, statistical power distribution, and overall platform health.

**Why this priority**: Platform analytics provide organizational insights but are not essential for individual experiments.

**Independent Test**: Can be tested by having several experiments in various states and verifying the dashboard metrics aggregate correctly.

**Acceptance Scenarios**:

1. **Given** 15 experiments exist (8 running, 4 concluded this month, 3 draft), **When** the analyst views the platform dashboard, **Then** it shows "8 active", "4 concluded this month", and the correct average duration for concluded experiments.
2. **Given** concluded experiments with varying statistical power, **When** the analyst views the power distribution chart, **Then** it shows a histogram of achieved statistical power across experiments.

---

### US20 — Analyst Creates Custom Metric Definitions (Priority: P5)

A Data Analyst creates custom metric definitions including composite metrics (sum of multiple events), ratio metrics (conversions/sessions), and funnel metrics (multi-step conversion funnels).

**Why this priority**: Custom metrics enable sophisticated analysis but basic metrics (simple conversion counts) are sufficient for initial use.

**Independent Test**: Can be tested by defining a ratio metric and verifying the statistical engine correctly computes results using the custom definition.

**Acceptance Scenarios**:

1. **Given** an analyst defines a ratio metric "revenue_per_user" = sum(purchase_value) / count(unique_users), **When** this metric is attached to an experiment, **Then** results show the per-variant revenue per user with confidence intervals.
2. **Given** an analyst defines a funnel metric "checkout_funnel" = [add_to_cart → checkout_started → payment_completed], **When** results are computed, **Then** per-step conversion rates and the overall funnel conversion rate are shown per variant.

---

### US21 — PM Views Experiment Timeline (Priority: P5)

A Product Manager views an experiment timeline showing all experiments that have run on a given feature or page, presented as a Gantt-style timeline view.

**Why this priority**: The timeline view provides historical context but is not required for running individual experiments.

**Independent Test**: Can be tested by creating multiple experiments targeting the same feature, concluding some, and verifying the timeline renders correctly.

**Acceptance Scenarios**:

1. **Given** 5 experiments have targeted the "checkout page" over the past 6 months, **When** the PM views the experiment timeline for "checkout page", **Then** a Gantt-style chart shows each experiment's duration, status, and outcome.
2. **Given** two experiments overlapped in time, **When** the PM views the timeline, **Then** the overlapping periods are visually highlighted.

---

### Edge Cases

- **Running experiment modification**: When traffic allocation is changed on a running experiment, existing user assignments are preserved (no flip-flopping). Only new users entering the experiment follow the updated allocation. The old allocation and the change timestamp are recorded in the audit log.

- **Assignment service unavailability**: When the assignment service is unreachable, the SDK fails open — it returns the control variant for all users. The SDK caches the most recent experiment configuration locally (with a configurable TTL) to reduce dependency on the central service. All fallback events are tagged so they can be excluded from statistical analysis.

- **Kafka unavailability**: When Kafka is unreachable, the event collector buffers events in a local disk-backed queue with retry and exponential backoff. No events are lost. Once Kafka recovers, buffered events are replayed in order. The buffer has a configurable maximum size (default: 1GB); if the buffer fills, the collector returns 503 with a Retry-After header to apply backpressure to clients.

- **Bot/crawler filtering**: Events from known bot user agents are tagged at ingestion time using a regularly updated bot detection list. Tagged events are excluded from statistical analysis by default. Admins can configure additional bot detection rules (e.g., rate-based detection: users with more than 1,000 events/minute are flagged).

- **Peeking problem (early significance)**: The platform uses sequential analysis with alpha-spending functions (O'Brien-Fleming boundaries by default) to control false-positive rates when experimenters view results repeatedly. The system displays the adjusted significance threshold at the current sample size. Users are warned if they attempt to conclude an experiment before reaching the minimum recommended sample size.

- **Anonymous user identity stitching** *(Deferred to v2)*: When an anonymous user (identified by device ID or session ID) later authenticates, the platform merges their event history under the authenticated user_id. Assignment is recalculated based on the authenticated user_id. If the authenticated user_id was already assigned a different variant, the authenticated identity takes precedence. Events collected during the anonymous phase are re-attributed. **Note: This feature is deferred to v2. It requires substantial infrastructure for event re-attribution and identity graph management that is out of scope for the initial release.**

- **Overlapping experiments on same UI element (interaction effects)**: When two experiments modify the same UI element, the platform warns the PM at creation time (if both experiments target the same feature tag). Experiments can be placed in mutual exclusion groups to prevent overlap. If interaction is allowed, the audit log records the concurrent experiments for post-hoc analysis.

- **Concurrent experiment modification by multiple editors**: When two editors modify the same experiment simultaneously, optimistic locking with a version counter detects the conflict. The first write succeeds; the second receives HTTP 409 Conflict with the current version, and must re-read before retrying. The dashboard should display a user-friendly conflict resolution message.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Experiment Lifecycle Management

- **FR-001**: System MUST allow creating an experiment with: name, hypothesis, description, variants (2+), traffic allocation per variant, and primary metric.
- **FR-002**: System MUST enforce an experiment state machine with states: draft → running → paused → concluded. Transitions: draft→running (launch), running→paused (pause), paused→running (resume), running→concluded (conclude), paused→concluded (conclude).
- **FR-003**: System MUST prevent invalid state transitions (e.g., concluded→running, draft→concluded).
- **FR-004**: System MUST validate that traffic allocation percentages sum to exactly 100% before saving an experiment.
- **FR-005**: System MUST require a hypothesis and at least one primary metric before an experiment can transition from draft to running.
- **FR-006**: System MUST support modification of experiment metadata (name, description) while in any state, but traffic allocation changes are only allowed in draft and running states. Concurrent modifications by multiple editors are resolved via optimistic locking: each experiment carries a version counter, writes include the expected version, and stale updates are rejected with HTTP 409 Conflict.
- **FR-007**: System MUST record the conclusion decision (ship variant X / revert to control / inconclusive) and a free-text rationale when an experiment is concluded.
- **FR-008**: System MUST prevent restarting a concluded experiment. Users must create a new experiment instead.

#### Variant Assignment

- **FR-009**: System MUST assign users to variants deterministically using MurmurHash3: given the same (user_id, experiment_id) pair, the same variant is always returned. MurmurHash3 is the mandated algorithm for its speed, excellent uniformity, and cross-platform availability.
- **FR-010**: System MUST produce uniform distribution across variants, verifiable by chi-squared test (p > 0.05) on 100,000+ assignments.
- **FR-011**: System MUST support assignment for experiments with 2 to 20 variants.
- **FR-012**: System MUST return the control variant when an experiment is not in "running" state.
- **FR-013**: System MUST support batch assignment — retrieving variants for a single user across multiple experiments in one request.
- **FR-014**: System MUST preserve existing assignments when traffic allocation is changed on a running experiment (no flip-flopping for already-assigned users).
- **FR-015**: System MUST support an assignment override mechanism allowing specific users to be force-assigned to a variant (for QA and testing).

#### Event Ingestion

- **FR-016**: System MUST accept individual metric events containing: experiment_id, user_id, event_type (conversion, metric, revenue), event_name, numeric value (optional), custom properties (optional), timestamp, and idempotency_key.
- **FR-017**: System MUST accept batch event submissions (up to 1,000 events per batch).
- **FR-018**: System MUST deduplicate events using the idempotency_key — duplicate submissions are silently accepted but only persisted once.
- **FR-019**: System MUST validate event schema on ingestion and reject malformed events with descriptive error messages while still processing valid events in the same batch.
- **FR-020**: System MUST accept events even if the referenced experiment has concluded (late-arriving events are common) and tag them with a "post-conclusion" label.
- **FR-021**: System MUST tag events from suspected bots or crawlers based on user-agent detection. Tagged events are excluded from analysis by default.

#### Statistical Engine

- **FR-022**: System MUST compute frequentist analysis for binary metrics using a z-test for proportions, returning: p-value, 95% confidence interval for the difference, observed effect size, and statistical power achieved.
- **FR-023**: System MUST compute frequentist analysis for continuous metrics using Welch's t-test, returning: p-value, 95% confidence interval for the mean difference, and Cohen's d effect size.
- **FR-024**: System MUST compute Bayesian analysis for binary metrics using a Beta-Binomial conjugate model, returning: probability-to-be-best for each variant, 95% credible interval, and expected loss.
- **FR-025**: System MUST compute Bayesian analysis for continuous metrics using a Normal-Normal conjugate model, returning: probability-to-be-best and 95% credible interval.
- **FR-026**: System MUST apply multiple comparison corrections (Bonferroni or Holm-Šidák) when an experiment has more than two variants.
- **FR-027**: System MUST implement sequential analysis with configurable alpha-spending functions (O'Brien-Fleming by default) to control false-positive rates under repeated testing.
- **FR-028**: System MUST calculate required minimum sample size given: baseline conversion rate, minimum detectable effect, statistical power (default 80%), and significance level (default 5%).
- **FR-029**: System MUST warn users when results are viewed before reaching the calculated minimum sample size.
- **FR-030**: System MUST produce results reproducible to within 0.1% given the same input data and configuration.

#### Targeting and Segmentation

- **FR-031**: System MUST support targeting rules based on user properties (key-value pairs passed at assignment time). Supported operators: equals, not equals, contains, in list, greater than, less than.
- **FR-032**: System MUST support compound targeting rules with AND/OR logic.
- **FR-033**: System MUST support percentage-based targeting (e.g., "only 30% of eligible users").
- **FR-034**: System MUST evaluate targeting rules at assignment time and exclude non-matching users from the experiment (they receive the default/control experience).
- **FR-035**: System MUST preserve existing assignments when targeting rules are modified on a running experiment.

#### Mutual Exclusion Groups

- **FR-036**: System MUST support creating mutual exclusion groups (experiment layers) that contain one or more experiments.
- **FR-037**: System MUST guarantee that a user assigned to one experiment in a mutual exclusion group cannot be assigned to another experiment in the same group.
- **FR-038**: System MUST support configuring the traffic split among experiments within a mutual exclusion group (e.g., experiment A gets 50%, experiment B gets 30%, holdout 20%).

#### Experiment Overlap Detection

- **FR-075**: System MUST warn the PM at experiment creation time when another running experiment targets the same `feature_tag`, displaying the overlapping experiment names and suggesting mutual exclusion group placement. The `feature_tag` is an optional string field on the experiment (e.g., "checkout-page", "pricing-hero") used to group experiments that modify the same area. The warning is returned as a `warnings` array in the experiment creation response.

#### Multi-Tenancy

- **FR-039**: System MUST isolate all data by tenant using row-level security (RLS) — a single database schema with a `tenant_id` column on every tenant-scoped table and PostgreSQL RLS policies enforcing isolation. No query or operation may return data from a different tenant.
- **FR-040**: System MUST authenticate all requests using tenant-scoped API keys.
- **FR-041**: System MUST support creating, listing, revoking, and regenerating API keys per tenant. API keys have no automatic expiry by default — they remain valid until manually revoked. An optional configurable TTL can be set per key at creation time.
- **FR-042**: System MUST support role-based access control with at least three roles: viewer (read-only), editor (create/modify experiments), and admin (full access including tenant management).
- **FR-043**: System MUST enforce RBAC on every operation — unauthorized actions return 403 with a descriptive message.

#### SDK Contract

- **FR-044**: System MUST provide a variant assignment endpoint that accepts: user_id, experiment_key, and optional user attributes (for targeting). Response returns: variant_key, experiment_id, variant_id, is_control, assigned_at, and an `enrolled` boolean indicating whether the user was actually enrolled in the experiment (true) or received a fallback/control response (false). The `enrolled` field MUST be present in all assignment responses (single and batch) for SDK consistency.
- **FR-045**: System MUST provide an event tracking endpoint that accepts single or batch events as defined in FR-016/FR-017.
- **FR-046**: System MUST provide a feature flag evaluation endpoint that accepts: flag_key, user_id, and optional user attributes. Response returns: enabled (boolean), variant_key, and flag metadata.

#### Feature Flags

- **FR-047**: System MUST support creating feature flags with a key, name, description, and default state (on/off).
- **FR-048**: System MUST support percentage-based rollout for feature flags (e.g., enabled for 10% of users) using the same deterministic assignment mechanism as experiments.
- **FR-049**: System MUST support monotonic rollout — when the percentage increases, all users who previously received "on" continue to receive "on".
- **FR-050**: System MUST support targeting rules on feature flags using the same targeting rule engine as experiments.

#### Data Retention and Archival

- **FR-051**: System MUST retain raw event data for a configurable period (default 90 days).
- **FR-052**: System MUST retain aggregated experiment results permanently (even after raw events are archived).
- **FR-053**: *(Deferred to post-v1)* System SHOULD support archiving experiments: archived experiments are hidden from the default list view but remain accessible via search and direct link. **Rationale**: Archival requires list filtering and archive/unarchive endpoints. Low priority for initial release — concluded experiments already have a distinct status. Will be implemented when experiment volume makes list navigation cumbersome. **Note**: The `archived` column is included in the data model for forward-compatibility, but no UI or API endpoint will expose it in v1.

#### Dashboard and Reporting

- **FR-054**: System MUST provide an experiment list view sortable by creation date, status, and name, with search and filter capabilities.
- **FR-055**: System MUST provide an experiment creation wizard that guides PMs through hypothesis, variant, traffic, and metric configuration.
- **FR-056**: System MUST provide an experiment detail view with: variant comparison table, confidence interval chart, cumulative conversion over time chart, and statistical result summary.
- **FR-057**: System MUST support near-real-time result updates on the experiment detail view (within 2 minutes of new events).
- **FR-058**: System MUST support exporting experiment results in CSV, JSON, and Excel formats.
- **FR-059**: System MUST provide a platform-wide analytics dashboard showing: count of active experiments, concluded experiments this month, average experiment duration, and statistical power distribution.

#### Custom Metrics

- **FR-060**: System MUST support defining custom metrics including: simple count (count of events), ratio (numerator event / denominator event), and sum (sum of event values).
- **FR-061**: System MUST support funnel metrics — ordered sequence of events measuring step-by-step conversion.
- **FR-062**: System MUST allow attaching multiple metrics to an experiment: one primary metric and zero or more secondary metrics.

#### Guardrails

- **FR-063**: System MUST support configuring guardrail metrics on an experiment with breach thresholds (e.g., "error_rate > 5%").
- **FR-064**: System MUST automatically pause an experiment when a guardrail threshold is breached, recording the specific guardrail and breach magnitude.
- **FR-065**: System MUST evaluate guardrails on every analysis cycle and not only on-demand.

#### Rate Limiting and Abuse Prevention

- **FR-066**: System MUST enforce per-API-key rate limits on all endpoints (configurable per tenant).
- **FR-067**: System MUST return standard rate limit headers (remaining requests, reset time) on every response.
- **FR-068**: System MUST reject requests exceeding the rate limit with a 429 status code and descriptive error.

#### Audit Trail

- **FR-069**: System MUST record an immutable audit entry for every experiment state change, configuration modification, and access control change.
- **FR-070**: System MUST include in each audit entry: actor (who), action (what), timestamp (when), before/after state (what changed), and an optional reason (why).
- **FR-071**: System MUST prevent modification or deletion of audit entries.

#### GDPR Compliance

- **FR-072**: System MUST support anonymizing all data for a specific participant_id (user_id) across all experiments and events upon request. Anonymization is defined as follows:
  - **Scope**: All records in `assignments`, `experiment_events_raw`, and `audit_logs` referencing the target `user_id` within the requesting tenant.
  - **Method**: Replace `user_id` with a deterministic, non-reversible pseudonym: `SHA-256(tenant_id || user_id || per-tenant-salt)` truncated to 32 hex chars. The per-tenant salt is stored in `tenants.settings` and MUST NOT be exposed via any API.
  - **Determinism rationale**: Using a deterministic pseudonym (rather than random UUIDs per record) preserves aggregate statistical validity — all records for the same original participant map to the same pseudonym, so variant assignments and event attributions remain internally consistent for analysis.
  - **Excluded from anonymization**: Aggregated experiment results (`experiment_results_daily`, `statistical_analyses`) are NOT modified, as they contain no participant-level identifiers.
  - **Audit trail**: An audit log entry MUST be created recording the anonymization request (actor, timestamp, target participant count, tenant_id). The audit entry itself uses the pseudonymized user_id.
  - **Execution**: Anonymization MUST be performed as a single database transaction per tenant. For participants with >100K records, processing MAY be executed as a background job with progress tracking via `GET /api/v1/gdpr/anonymization-requests/:id`.
  - **Irreversibility**: Once anonymized, the original `user_id` cannot be recovered. The system MUST return a confirmation response including the count of records anonymized per table.
- **FR-073**: System MUST support deleting all data for a specific tenant upon request (tenant offboarding). Deletion removes all rows across all tenant-scoped tables and is irreversible. A 72-hour soft-delete grace period (tracked via `deletion_scheduled_at` on the tenant record) allows cancellation before permanent deletion. During the grace period, the tenant's API keys are immediately disabled, but data remains accessible to superadmins for review.
- **FR-074**: System MUST log all data access for compliance auditing purposes.

### Non-Functional Requirements

- **NFR-001**: Assignment latency MUST be less than 5ms at the 99th percentile under a sustained load of 10,000 requests per second.
- **NFR-002**: Event ingestion throughput MUST exceed 50,000 events per second sustained.
- **NFR-003**: Dashboard pages MUST load in less than 2 seconds, including experiment result aggregation queries against 10M+ events.
- **NFR-004**: Assignment endpoint availability MUST be 99.9% or higher (less than 8.7 hours downtime per year).
- **NFR-005**: Raw event data MUST be retained for at least 90 days. Aggregated results MUST be retained permanently.
- **NFR-006**: System MUST support at least 100 concurrent experiments per tenant without performance degradation.
- **NFR-007**: System MUST support GDPR-compliant data handling including user data anonymization and tenant data deletion.
- **NFR-008**: Statistical computations MUST complete within 30 seconds for experiments with up to 1 million observations per variant.
- **NFR-009**: System MUST support up to 5 tenants in v1, designed for 10x growth without architectural changes.
- **NFR-010**: All services MUST expose health check endpoints and structured logs for operational monitoring.

### Key Entities

- **Experiment**: A test comparing two or more variants. Has a name, hypothesis, status (draft/running/paused/concluded), traffic allocation, start/end dates, conclusion decision, associated metrics, and an optional **feature_tag** (string) for grouping experiments targeting the same feature or page. The feature_tag is used for overlap detection (FR-075) and timeline views (US21). Belongs to a Tenant.
- **Variant**: A specific treatment within an experiment. Has a key, name, description, and traffic allocation percentage. One variant per experiment is designated as the control.
- **ExperimentGroup (Mutual Exclusion)**: A named group of experiments where a user can only participate in one experiment at a time. Contains traffic allocation across member experiments.
- **Metric**: An instance of a MetricDefinition attached to an experiment, designated as primary, secondary, or guardrail. Includes guardrail threshold settings if applicable.
- **MetricDefinition**: A reusable metric template (e.g., "checkout conversion rate") defining the event(s) to count, the computation type (count, ratio, sum, funnel), and default thresholds.
- **Assignment**: A record of which variant a participant (`user_id`) received for a given experiment. Deterministic and immutable once created. The `user_id` here refers to the external participant identifier, not an ExperimentHub dashboard user.
- **Event**: A participant action (conversion, metric value, revenue) associated with an experiment. Contains participant `user_id`, event type, value, properties, timestamp, and idempotency key. The `user_id` field refers to the external participant identifier.
- **ExperimentResult**: Computed statistical analysis for an experiment, including per-variant metrics, frequentist results, Bayesian results, sample sizes, and analysis timestamp.
- **StatisticalAnalysis**: A detailed record of a single analysis run, including methodology used, inputs, parameters, outputs, and sequential analysis boundaries.
- **Tenant**: An organization using the platform. All data is scoped to a tenant. Has a name, configuration, and associated API keys and users.
- **User**: A person who accesses the ExperimentHub dashboard. Belongs to a Tenant and has a Role.
- **APIKey**: A cryptographically secure key used for authenticating SDK and API requests. Scoped to a Tenant. Can be created, listed, and revoked.
- **Permission/Role**: An access level within a tenant. Roles: viewer (read-only), editor (create/modify experiments), admin (full access).
- **AuditLog**: An immutable, append-only record of every significant action in the system. Contains actor, action, timestamp, before/after state, and reason.
- **TargetingRule**: A condition or set of conditions that determines which users are eligible for an experiment or feature flag. Based on user attributes with supported operators.
- **Segment**: A named, reusable group of targeting rules (e.g., "US Mobile Users") that can be applied to multiple experiments.
- **FeatureFlag**: A simplified experiment used for on/off feature toggles and percentage-based rollouts. Shares the assignment infrastructure with experiments.

---

## Assumptions

The following reasonable defaults are assumed where the master prompt did not specify:

1. **Authentication for dashboard users**: Standard email/password login with session-based authentication. OAuth/SSO integration is deferred beyond v1.
2. **Notification mechanism for guardrail breaches**: In-app notifications on the dashboard. Email/Slack notifications are deferred beyond v1.
3. **Default statistical significance level**: 5% (alpha = 0.05) unless configured otherwise per experiment.
4. **Default statistical power**: 80% (beta = 0.20) for sample size calculations.
5. **Maximum variants per experiment**: 20 variants. This accommodates multivariate testing while preventing unreasonably large experiments.
6. **Maximum events per batch**: 1,000 events per batch request. Larger batches should be split client-side.
7. **Assignment cache TTL**: SDK-side cache of 5 minutes. Server-side Redis cache with experiment-specific invalidation on config changes.
8. **Bot detection**: User-agent based detection using a standard bot list, supplemented by configurable rate-based detection rules.
9. **Data export size limits**: Export operations limited to experiments with up to 10 million events. Larger datasets can be exported via a scheduled background job.
10. **Timezone handling**: All timestamps stored in UTC. Dashboard displays in the user's local timezone.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An experiment can be created, launched, and concluded within 5 minutes via the UI, measured by user testing with 5 Product Managers.
- **SC-002**: The assignment SDK adds less than 2ms overhead to application response time, measured under a load of 10,000 concurrent requests per second.
- **SC-003**: The statistical engine produces results matching R and scipy reference implementations within 0.1% margin on 5 benchmark datasets covering: equal rates, clear winner, small effect size, multivariate, and sequential analysis scenarios.
- **SC-004**: The platform handles 10 concurrent experiments with 1 million users each (10M total active user-experiment pairs) without degradation in assignment latency (< 5ms p99) or dashboard load time (< 2 seconds).
- **SC-005**: A new software engineer can integrate the SDK and run their first experiment end-to-end within 30 minutes using only the provided documentation.
- **SC-006**: Multi-tenant isolation verified by automated tests: authenticated requests for tenant A never return tenant B data across 10,000 randomized test operations.
- **SC-007**: Experiment audit trail covers 100% of state changes and configuration modifications with correct actor, timestamp, and change details.
- **SC-008**: Guardrail metrics pause experiments within 2 analysis cycles of a threshold breach, verified by automated tests.
