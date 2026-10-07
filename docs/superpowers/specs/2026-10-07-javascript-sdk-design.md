# JavaScript SDK (`@experiment-hub/sdk`) — design

**Date:** 2026-10-07 · **Status:** approved (approach A, "thin typed client") ·
**Sub-project 1 of 2.** Sub-project 2 (integrating dhruvsinghal.codes as the
first real tenant) gets its own spec once this ships.

## 1. Problem

ExperimentHub only does something when an application calls it: `POST
/v1/assign` to pick a variant and `POST /v1/events` to report what the user
did. Today the only clients are a PowerShell smoke script and k6 load scripts.
`docs/sdk/javascript-quickstart.md` documents an `@experiment-hub/sdk` npm
package that does not exist, with field names (`context`, `experimentId` on
events) that the server does not accept, and `docs/api-reference.md` documents
routes (`POST /assignments`, `/experiments/:id/launch`) that the router does
not expose. Anyone trying to integrate hits a wall of drift.

## 2. Goal

Ship the package the docs promise, written against the router as it actually
is, with a contract test that fails the moment the server and the SDK
disagree again.

## 3. Non-goals (explicitly deferred)

- Local assignment cache, event queue with background flush, offline buffer,
  automatic retries. The server already makes assignments sticky and dedupes
  events on `idempotency_key`; callers that need retries wrap one call.
- `@experiment-hub/react` hooks. Sub-project 2 uses Next.js server-side
  assignment where the variant is a prop; a hook would have nothing to do.
- Management API (create/start/pause experiments, metric definitions, users).
  The SDK covers the **runtime** surface only.
- Publishing to npm. The package is consumed from the monorepo by path.
- An OpenAPI spec. Worth doing for the platform later; not a prerequisite.

## 4. Package

| | |
|---|---|
| Path | `sdk/javascript/` (matches `docs/sdk/javascript-quickstart.md`) |
| Name / version | `@experiment-hub/sdk` / `0.1.0` |
| Runtime | Node ≥ 18 (native `fetch`, `AbortController`, `crypto.randomUUID`); also runs in modern browsers and edge runtimes, but the API key is a tenant secret and must stay server-side |
| Build | `tsup` → `dist/index.js` (ESM), `dist/index.cjs` (CJS), `dist/index.d.ts` |
| Language / tooling | TypeScript 5 strict, mirrors `dashboard/tsconfig.json` flags; ESLint 9 flat config; vitest 4 |
| Runtime dependencies | **none** |
| Scripts | `build`, `typecheck`, `lint`, `test` (unit), `test:contract` (live stack), `check` (typecheck + lint + test + build) |

## 5. Public API

```ts
import { createClient } from "@experiment-hub/sdk";

const hub = createClient({
  baseUrl: "http://127.0.0.1:4000",
  apiKey: process.env.EXPERIMENT_HUB_API_KEY!,
  timeoutMs: 2000,             // optional, default 2000
  fetch: customFetch,          // optional, default globalThis.fetch (tests inject a stub)
  headers: { "x-trace": "…" }, // optional extra headers on every request
});
```

All inputs and outputs are camelCase TypeScript; the SDK maps to and from the
server's snake_case wire format. Every method returns a Promise and accepts an
optional trailing `{ signal?: AbortSignal }`.

### 5.1 Assignment

```ts
hub.assign({ userId, experimentKey, attributes? }) → Assignment
hub.assignBatch({ userId, experimentKeys, attributes? }) → BatchAssignment
```

Wire: `POST /v1/assign` `{ user_id, experiment_key, attributes }` and
`POST /v1/assign/batch` `{ user_id, experiment_keys, attributes }`.

```ts
interface Assignment {
  experimentKey: string; experimentId: string;
  variantKey: string;    variantId: string;   variantName: string;
  isControl: boolean;
  /** false ⇒ experiment not running (draft/paused/concluded) or user not
   *  targeted; the server returned the control variant as a safe default and
   *  recorded nothing. Treat as "show the baseline". */
  enrolled: boolean;
  assignedAt: string; // ISO 8601
}
interface BatchAssignment {
  userId: string; assignedAt: string;
  assignments: Array<
    | { experimentKey; variantKey; experimentId; variantId; isControl; enrolled }
    | { experimentKey; error: string }   // per-item failure, e.g. "experiment_not_found"
  >;
}
```

`assign` throws `NotFoundError` for an unknown experiment key (server 404).
`assignBatch` never throws per-item; unknown keys come back as `{ error }`
entries, mirroring the server.

### 5.2 Events

```ts
hub.track(event: TrackInput) → EventReceipt
hub.trackBatch(events: TrackInput[]) → BatchEventReceipt

interface TrackInput {
  userId: string;
  type: "conversion" | "metric" | "revenue";
  name: string;                 // metric event_name, e.g. "checkout_conversion"
  value?: number;               // required by the server for metric/revenue
  timestamp?: string | Date;    // default: now
  idempotencyKey?: string;      // default: crypto.randomUUID()
  properties?: Record<string, unknown>;
}
```

Wire: `POST /v1/events` `{ user_id, event_type, event_name, value, timestamp,
idempotency_key, properties }`; batch `POST /v1/events/batch` `{ events: [...] }`.

Events carry **no experiment or variant field**: the pipeline joins events to
assignments by `user_id`. The SDK's types make that impossible to get wrong.

Client-side pre-validation (throws `ValidationError` before any network call,
so the failure is attributable to the caller, not the server): `userId` and
`name` non-empty, `type` in the allowed set, `value` present for
`metric`/`revenue`, batch length 1–1000. Nothing else is validated locally;
the server remains the source of truth and its 400 body is surfaced verbatim.

```ts
interface EventReceipt { status: "accepted"; eventId: string; receivedAt: string }
interface BatchEventReceipt {
  status: "accepted" | "partial" | "rejected";
  accepted: number; rejected: number;
  errors: Array<{ index: number; error: string; details: Array<{ field: string; error: string }> }>;
}
```

`trackBatch` resolves (does not throw) on partial acceptance; it throws
`ValidationError` only when the server rejected **every** event (400).

### 5.3 Feature flags

```ts
hub.flags.evaluate({ key, context? }) → { key: string; enabled: boolean }
hub.flags.evaluateBatch({ keys, context? }) → Array<{ key; enabled }>
```

Wire: `POST /api/v1/flags/evaluate` `{ key, context }` and
`POST /api/v1/flags/evaluate/batch` `{ keys, context }`. `evaluate` throws
`NotFoundError` on 404.

**Risk to verify in the contract test:** the controller reads
`conn.assigns[:current_scope].tenant_id`. If `ApiKeyAuth` does not populate
`current_scope`, API-key callers get a 500. The contract test exercises this
path; if it fails, the fix is a one-line server change in
`feature_flag_controller.ex` (read `conn.assigns.tenant_id`, as the assign and
event controllers do) and is in scope for this sub-project.

### 5.4 Errors

One base class, subclassed by what the caller would branch on:

| Class | When | Extra fields |
|---|---|---|
| `ExperimentHubError` | base; never thrown directly | `status?: number`, `code: string`, `details?: unknown` |
| `ValidationError` | local pre-validation, or server 400 | `details` = server `details` array when present |
| `AuthenticationError` | 401 | |
| `NotFoundError` | 404 | |
| `RateLimitError` | 429 | `retryAfterMs` parsed from `Retry-After` (seconds → ms); `limit`, `remaining`, `resetAt` from `x-ratelimit-*` when present |
| `ServiceUnavailableError` | 503 (Kafka enqueue failed) | |
| `NetworkError` | `fetch` rejected, DNS failure, or timeout (`code: "timeout"`) | `cause` |
| `ApiError` | any other non-2xx | raw body as `details` |

`message` is the server's `message` field when the body is JSON with one,
else a generic `"<METHOD> <path> failed with <status>"`.

The SDK has **no fail-open behaviour**: `assign` throws when the platform is
unreachable. Fail-open is an application policy (sub-project 2 implements
`assignOrControl` in the portfolio with a 300 ms budget); baking it into the
SDK would hide outages from the one place that should notice them.

### 5.5 Transport

- Headers on every request: `X-API-Key`, `Content-Type: application/json`,
  `Accept: application/json`, `User-Agent: experiment-hub-sdk-js/<version>`
  (Node only; browsers forbid setting it), plus `config.headers`.
- Timeout via `AbortController`; the caller's `signal` is also honoured.
- No retries, no caching, no global state. `createClient` is pure; two clients
  with different keys coexist.

## 6. Internal structure

```
sdk/javascript/
  package.json  tsconfig.json  tsup.config.ts  eslint.config.js  vitest.config.ts
  README.md
  src/
    index.ts          # public re-exports only
    client.ts         # createClient: wires transport into the three method groups
    transport.ts      # request(): headers, timeout, JSON, status → error mapping
    errors.ts         # error classes + fromResponse(status, headers, body)
    assign.ts         # assign / assignBatch + wire mapping
    events.ts         # track / trackBatch + pre-validation + defaults
    flags.ts          # flags.evaluate / evaluateBatch
    types.ts          # all public interfaces
  test/
    helpers/fake-fetch.ts   # records requests, returns scripted responses
    transport.test.ts  errors.test.ts  assign.test.ts  events.test.ts  flags.test.ts
    contract/
      live.contract.test.ts   # skipped unless EXPERIMENT_HUB_BASE_URL + API key set
```

Each file has one job and is testable through its exports; `transport.ts` is
the only place that touches `fetch`.

## 7. Testing

**Unit (always run, no network).** A `fakeFetch` helper captures the exact
request (URL, method, headers, parsed body) and returns a scripted
`Response`. Coverage targets, per method: correct path and wire body; response
mapped to camelCase; each error status → the right class with the right
fields; timeout → `NetworkError{code:"timeout"}`; `track` fills
`timestamp`/`idempotency_key` only when absent; local validation throws
before `fetch` is called; batch size guard; `enrolled:false` passes through
untouched.

**Contract (opt-in, against the running local stack).** Enabled by
`EXPERIMENT_HUB_BASE_URL` and `EXPERIMENT_HUB_API_KEY`; otherwise the suite
is reported as skipped, not passed. Uses the `mix dev.demo` tenant:

1. `assign` on `checkout-copy-demo` (running) → `enrolled:true`; a second call
   with the same user returns the same `variantKey` (stickiness).
2. `assign` on `pricing-layout-demo` (paused) → `enrolled:false`, `isControl:true`.
3. `assign` on `does-not-exist` → `NotFoundError`.
4. `assignBatch` with one good and one unknown key → one assignment, one `{error}`.
5. `track` conversion → `status:"accepted"`; `track` metric without `value` →
   local `ValidationError`, and the same payload forced through raw `fetch`
   → server 400 (proves the local rule mirrors the server).
6. `trackBatch` with 1 valid + 1 invalid → `status:"partial"`, `accepted:1`.
7. `flags.evaluate` on a seeded flag → boolean (this is the `current_scope`
   probe); unknown key → `NotFoundError`.
8. Wrong API key → `AuthenticationError`.

**CI.** New `sdk-js` job in `.github/workflows/ci.yml`: Node 24, `npm ci`,
`npm run check`. Contract tests are not run in CI for now (no stack there);
the `release-smoke-test` job is the natural future home.

## 8. Documentation changes (in scope)

- `sdk/javascript/README.md`: install-from-path, the three method groups,
  error handling, a fail-open example, how to run contract tests.
- Rewrite `docs/sdk/javascript-quickstart.md` to match the real API
  (`attributes` not `context`; events have no experiment field; no React
  package yet).
- Fix `docs/api-reference.md` runtime sections to the real routes:
  `POST /v1/assign`, `POST /v1/assign/batch`, `POST /v1/events`,
  `POST /v1/events/batch`, `POST /api/v1/flags/evaluate[/batch]`, and
  `/experiments/:id/start` (not `/launch`).
- README.md: add the SDK to the repo layout table and a one-paragraph
  "Integrating an application" pointer.

## 9. Open questions resolved during design

- **`context` vs `attributes`:** the server reads `params["attributes"]`
  (`assignments.ex:26`). SDK uses `attributes`; docs were wrong.
- **Where does the event say which experiment it belongs to?** It doesn't;
  the join is on `user_id`. `TrackInput` deliberately has no such field.
- **Do non-running experiments error?** No — control + `enrolled:false`
  (`assignments.ex:185-200`). Surfaced as a typed boolean, documented inline.
- **tsup vs plain tsc:** tsup, for dual ESM/CJS output without two tsconfigs.
  It is a devDependency only; the shipped package still has zero runtime deps.
