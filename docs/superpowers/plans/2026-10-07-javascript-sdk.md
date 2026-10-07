# JavaScript SDK (`@experiment-hub/sdk`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `sdk/javascript/` — a zero-dependency TypeScript client for ExperimentHub's runtime API (assign, events, flags) with unit tests, a live contract suite, CI, and corrected docs.

**Architecture:** One `createClient(config)` factory wires a single `transport.post()` (headers, timeout, JSON, status→typed error) into three small method groups (`assign.ts`, `events.ts`, `flags.ts`). Public types are camelCase; each method group owns its snake_case wire mapping. Errors are a class hierarchy callers can `instanceof`. No retries, cache, or global state.

**Tech Stack:** TypeScript 5 (strict), tsup (ESM+CJS+d.ts), vitest 4, ESLint 9 flat config + typescript-eslint, Node 24 (native `fetch`, `AbortController`, `crypto.randomUUID`).

**Spec:** `docs/superpowers/specs/2026-10-07-javascript-sdk-design.md`

## Global Constraints

- Package path `sdk/javascript/`, name `@experiment-hub/sdk`, version `0.1.0`, `"private": false`, not published.
- **Zero runtime dependencies.** Everything is a devDependency.
- Node ≥ 18 (`"engines": {"node": ">=18"}`); CI uses Node 24.
- Wire format is snake_case; public API is camelCase. Assignment attributes are sent as `attributes` (NOT `context`). Events carry `experiment_id` (required, UUID) and `variant_id` (UUID), both taken from the assign response — the rollup pipeline buckets by them.
- **Amended 2026-10-07 during execution:** the first live contract run showed events need `experiment_id`/`variant_id`; the Task 5 and Task 8 code blocks below predate that and are superseded by spec §5.2 and `.superpowers/sdd/2026-10-07-javascript-sdk/task-8-addendum.md` (Rulings 5–7). Task 8 also fixed a server crash in `ExperimentHub.Targeting` (Ruling 6).
- Default timeout 2000 ms. No retries. No fail-open inside the SDK (`assign` throws on outage).
- Auth header is `X-API-Key`. Runtime routes: `POST /v1/assign`, `POST /v1/assign/batch`, `POST /v1/events`, `POST /v1/events/batch`, `POST /api/v1/flags/evaluate`, `POST /api/v1/flags/evaluate/batch`.
- Server responses: assign 200; events 202 (`status:"accepted"`), batch events 202/207/400 with `status` `"accepted"|"partial"|"rejected"`; 400 `{error:"validation_error",message,details:[{field,error}]}`; 401 `{error:"unauthorized",message}`; 404 `{error:"experiment_not_found"|"not_found",message?}`; 429 with `Retry-After` + `x-ratelimit-limit/remaining/reset`; 503 `{error:"service_unavailable",message}`.
- Git: stage by explicit path only (`git add <files>`); never `git add -A`/`.`; never push. Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Run every npm command from `sdk/javascript/`. Windows: the repo checkout is CRLF; do not run repo-wide formatters.
- Demo tenant (from `mix dev.demo`): running experiment `checkout-copy-demo`, paused `pricing-layout-demo`, seeded flag `checkout_reassurance` (enabled), conversion event name `checkout_completed`, revenue event name `order_completed`.

---

## File map

| File | Responsibility |
|---|---|
| `sdk/javascript/package.json` | name, scripts, devDeps, exports map |
| `sdk/javascript/tsconfig.json` | strict TS, `noEmit` (tsup emits) |
| `sdk/javascript/tsup.config.ts` | ESM + CJS + d.ts from `src/index.ts` |
| `sdk/javascript/eslint.config.js` | ESLint 9 flat + typescript-eslint recommended |
| `sdk/javascript/vitest.config.ts` | unit tests (`test/**/*.test.ts`, excludes `test/contract`) |
| `sdk/javascript/vitest.contract.config.ts` | contract tests only |
| `sdk/javascript/src/types.ts` | every public interface |
| `sdk/javascript/src/errors.ts` | error classes + `errorFromResponse` |
| `sdk/javascript/src/transport.ts` | `createTransport` → `{ post }` |
| `sdk/javascript/src/assign.ts` | `createAssignMethods(transport)` |
| `sdk/javascript/src/events.ts` | `createEventMethods(transport)` + `toWireEvent` |
| `sdk/javascript/src/flags.ts` | `createFlagMethods(transport)` |
| `sdk/javascript/src/client.ts` | `createClient(config)` |
| `sdk/javascript/src/index.ts` | public re-exports |
| `sdk/javascript/test/helpers/fake-fetch.ts` | scripted `fetch` that records requests |
| `sdk/javascript/test/*.test.ts` | unit tests per module |
| `sdk/javascript/test/contract/live.contract.test.ts` | opt-in live suite |
| `sdk/javascript/README.md` | usage docs |
| `.github/workflows/ci.yml` | new `sdk-js` job |
| `docs/sdk/javascript-quickstart.md`, `docs/api-reference.md`, `README.md` | doc corrections |

---

### Task 1: Package scaffold with a passing smoke test

**Files:**

- Create: `sdk/javascript/package.json`, `sdk/javascript/tsconfig.json`, `sdk/javascript/tsup.config.ts`, `sdk/javascript/eslint.config.js`, `sdk/javascript/vitest.config.ts`, `sdk/javascript/vitest.contract.config.ts`, `sdk/javascript/.gitignore`, `sdk/javascript/src/types.ts`, `sdk/javascript/src/index.ts`
- Test: `sdk/javascript/test/index.test.ts`

**Interfaces:**

- Produces: every public type in `src/types.ts` (copied below verbatim — later tasks import from it); `SDK_VERSION` constant.

- [ ] **Step 1: Create `sdk/javascript/package.json`**

```json
{
  "name": "@experiment-hub/sdk",
  "version": "0.1.0",
  "description": "TypeScript client for the ExperimentHub runtime API: variant assignment, event tracking, feature flags.",
  "license": "MIT",
  "type": "module",
  "main": "./dist/index.cjs",
  "module": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "import": "./dist/index.js",
      "require": "./dist/index.cjs"
    }
  },
  "files": ["dist", "README.md"],
  "engines": { "node": ">=18" },
  "sideEffects": false,
  "scripts": {
    "build": "tsup",
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:contract": "vitest run --config vitest.contract.config.ts",
    "check": "npm run typecheck && npm run lint && npm run test && npm run build"
  },
  "devDependencies": {
    "@eslint/js": "^9.17.0",
    "@types/node": "^24.0.0",
    "eslint": "^9.17.0",
    "tsup": "^8.3.5",
    "typescript": "^5.7.2",
    "typescript-eslint": "^8.18.0",
    "vitest": "^4.0.0"
  }
}
```

- [ ] **Step 2: Create `sdk/javascript/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "types": ["node"],
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "skipLibCheck": true,
    "noEmit": true,
    "declaration": true
  },
  "include": ["src", "test", "tsup.config.ts", "vitest.config.ts", "vitest.contract.config.ts"]
}
```

- [ ] **Step 3: Create `sdk/javascript/tsup.config.ts`**

```ts
import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["esm", "cjs"],
  dts: true,
  sourcemap: true,
  clean: true,
  target: "node18",
  treeshake: true,
});
```

- [ ] **Step 4: Create `sdk/javascript/eslint.config.js`**

```js
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist/**", "node_modules/**"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    rules: {
      "@typescript-eslint/consistent-type-imports": "error",
      "@typescript-eslint/no-explicit-any": "error",
    },
  },
);
```

- [ ] **Step 5: Create the two vitest configs and `.gitignore`**

`sdk/javascript/vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    exclude: ["test/contract/**", "node_modules/**", "dist/**"],
    environment: "node",
  },
});
```

`sdk/javascript/vitest.contract.config.ts`:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["test/contract/**/*.test.ts"],
    environment: "node",
    testTimeout: 15_000,
    // Contract tests share one tenant; run them in order, one at a time.
    fileParallelism: false,
    sequence: { concurrent: false },
  },
});
```

`sdk/javascript/.gitignore`:

```
node_modules/
dist/
```

- [ ] **Step 6: Create `sdk/javascript/src/types.ts`** (the full public type surface; later tasks import from here and must not redefine these)

```ts
/** Configuration for {@link createClient}. */
export interface ClientConfig {
  /** Origin of the ExperimentHub API, e.g. `http://127.0.0.1:4000`. Trailing slashes are ignored. */
  baseUrl: string;
  /** Tenant SDK key (`eh_live_…`). It is a secret: keep it server-side. */
  apiKey: string;
  /** Per-request timeout in milliseconds. Default 2000. */
  timeoutMs?: number;
  /** `fetch` implementation. Default `globalThis.fetch`. Tests inject a stub here. */
  fetch?: typeof globalThis.fetch;
  /** Extra headers sent on every request. */
  headers?: Record<string, string>;
}

/** Per-call options accepted by every client method. */
export interface RequestOptions {
  signal?: AbortSignal;
}

export type Attributes = Record<string, unknown>;

// ---------------------------------------------------------------- assignment

export interface AssignInput {
  userId: string;
  experimentKey: string;
  /** Targeting attributes evaluated by the server's targeting rules. */
  attributes?: Attributes;
}

export interface Assignment {
  experimentKey: string;
  experimentId: string;
  variantKey: string;
  variantId: string;
  variantName: string;
  isControl: boolean;
  /**
   * `false` means the experiment is not running (draft/paused/concluded) or
   * the user was not targeted. The server returned the control variant as a
   * safe default and recorded nothing. Treat as "show the baseline".
   */
  enrolled: boolean;
  /** ISO 8601 timestamp. */
  assignedAt: string;
}

export interface AssignBatchInput {
  userId: string;
  experimentKeys: string[];
  attributes?: Attributes;
}

export interface BatchAssignmentItem {
  experimentKey: string;
  experimentId: string;
  variantKey: string;
  variantId: string;
  isControl: boolean;
  enrolled: boolean;
}

export interface BatchAssignmentError {
  experimentKey: string;
  /** Server error code, e.g. `experiment_not_found`. */
  error: string;
}

export interface BatchAssignment {
  userId: string;
  assignedAt: string;
  assignments: Array<BatchAssignmentItem | BatchAssignmentError>;
}

/** Type guard for per-item batch failures. */
export function isBatchAssignmentError(
  item: BatchAssignmentItem | BatchAssignmentError,
): item is BatchAssignmentError {
  return "error" in item;
}

// -------------------------------------------------------------------- events

export type EventType = "conversion" | "metric" | "revenue";

export interface TrackInput {
  userId: string;
  type: EventType;
  /** The metric definition's `event_name`, e.g. `checkout_completed`. */
  name: string;
  /** Required by the server for `metric` and `revenue` events. */
  value?: number;
  /** Default: now. */
  timestamp?: string | Date;
  /** Default: `crypto.randomUUID()`. Reuse one key to make a retry idempotent. */
  idempotencyKey?: string;
  properties?: Record<string, unknown>;
}

export interface EventReceipt {
  status: "accepted";
  eventId: string;
  receivedAt: string;
}

export interface BatchEventError {
  /** Index into the submitted array. */
  index: number;
  error: string;
  details: Array<{ field: string; error: string }>;
}

export interface BatchEventReceipt {
  status: "accepted" | "partial" | "rejected";
  accepted: number;
  rejected: number;
  errors: BatchEventError[];
}

// --------------------------------------------------------------------- flags

export interface FlagEvaluateInput {
  key: string;
  context?: Record<string, unknown>;
}

export interface FlagEvaluateBatchInput {
  keys: string[];
  context?: Record<string, unknown>;
}

export interface FlagEvaluation {
  key: string;
  enabled: boolean;
}

// -------------------------------------------------------------------- client

export interface ExperimentHubClient {
  assign(input: AssignInput, options?: RequestOptions): Promise<Assignment>;
  assignBatch(input: AssignBatchInput, options?: RequestOptions): Promise<BatchAssignment>;
  track(event: TrackInput, options?: RequestOptions): Promise<EventReceipt>;
  trackBatch(events: TrackInput[], options?: RequestOptions): Promise<BatchEventReceipt>;
  flags: {
    evaluate(input: FlagEvaluateInput, options?: RequestOptions): Promise<FlagEvaluation>;
    evaluateBatch(input: FlagEvaluateBatchInput, options?: RequestOptions): Promise<FlagEvaluation[]>;
  };
}
```

- [ ] **Step 7: Create a placeholder `sdk/javascript/src/index.ts`** (Task 7 replaces it with the real re-exports)

```ts
export const SDK_VERSION = "0.1.0";
export * from "./types";
```

- [ ] **Step 8: Write the smoke test `sdk/javascript/test/index.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import { SDK_VERSION, isBatchAssignmentError } from "../src/index";

describe("package smoke", () => {
  it("exposes the SDK version", () => {
    expect(SDK_VERSION).toBe("0.1.0");
  });

  it("distinguishes batch assignment errors", () => {
    expect(isBatchAssignmentError({ experimentKey: "x", error: "experiment_not_found" })).toBe(true);
    expect(
      isBatchAssignmentError({
        experimentKey: "x",
        experimentId: "e",
        variantKey: "control",
        variantId: "v",
        isControl: true,
        enrolled: true,
      }),
    ).toBe(false);
  });
});
```

- [ ] **Step 9: Install and run the full check**

Run (from `sdk/javascript/`): `npm install` then `npm run check`
Expected: typecheck clean, lint clean, 2 tests pass, `dist/index.js`, `dist/index.cjs`, `dist/index.d.ts` produced. Confirm `dist/` is ignored: `git status --short sdk/javascript` must not list `dist/` or `node_modules/`.

- [ ] **Step 10: Commit**

```bash
git add sdk/javascript/package.json sdk/javascript/package-lock.json sdk/javascript/tsconfig.json sdk/javascript/tsup.config.ts sdk/javascript/eslint.config.js sdk/javascript/vitest.config.ts sdk/javascript/vitest.contract.config.ts sdk/javascript/.gitignore sdk/javascript/src/types.ts sdk/javascript/src/index.ts sdk/javascript/test/index.test.ts
git commit -m "feat(sdk-js): scaffold @experiment-hub/sdk with public types

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Error hierarchy

**Files:**

- Create: `sdk/javascript/src/errors.ts`
- Test: `sdk/javascript/test/errors.test.ts`

**Interfaces:**

- Produces: `ExperimentHubError`, `ValidationError`, `AuthenticationError`, `NotFoundError`, `RateLimitError`, `ServiceUnavailableError`, `NetworkError`, `ApiError`; `errorFromResponse(method: string, path: string, status: number, headers: Headers, body: unknown): ExperimentHubError`.

- [ ] **Step 1: Write the failing tests `sdk/javascript/test/errors.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import {
  ApiError,
  AuthenticationError,
  ExperimentHubError,
  NetworkError,
  NotFoundError,
  RateLimitError,
  ServiceUnavailableError,
  ValidationError,
  errorFromResponse,
} from "../src/errors";

const h = (init: Record<string, string> = {}) => new Headers(init);

describe("error classes", () => {
  it("carry code, status, details and a useful name", () => {
    const err = new ValidationError("bad", { details: [{ field: "x", error: "is required" }] });
    expect(err).toBeInstanceOf(ExperimentHubError);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("ValidationError");
    expect(err.code).toBe("validation_error");
    expect(err.status).toBe(400);
    expect(err.details).toEqual([{ field: "x", error: "is required" }]);
  });

  it("allow overriding the default code", () => {
    const err = new NetworkError("timed out", { code: "timeout" });
    expect(err.code).toBe("timeout");
    expect(err.status).toBeUndefined();
  });

  it("preserve cause", () => {
    const cause = new TypeError("fetch failed");
    const err = new NetworkError("boom", { cause });
    expect(err.cause).toBe(cause);
  });
});

describe("errorFromResponse", () => {
  it("maps 400 to ValidationError with the server message and details", () => {
    const err = errorFromResponse("POST", "/v1/events", 400, h(), {
      error: "validation_error",
      message: "value: is required for revenue events",
      details: [{ field: "value", error: "is required for revenue events" }],
    });
    expect(err).toBeInstanceOf(ValidationError);
    expect(err.message).toBe("value: is required for revenue events");
    expect(err.details).toEqual([{ field: "value", error: "is required for revenue events" }]);
  });

  it("maps 401 to AuthenticationError", () => {
    const err = errorFromResponse("POST", "/v1/assign", 401, h(), {
      error: "unauthorized",
      message: "Authentication required.",
    });
    expect(err).toBeInstanceOf(AuthenticationError);
    expect(err.code).toBe("unauthorized");
  });

  it("maps 404 to NotFoundError and keeps the server code", () => {
    const err = errorFromResponse("POST", "/v1/assign", 404, h(), {
      error: "experiment_not_found",
      message: "Experiment 'nope' does not exist",
    });
    expect(err).toBeInstanceOf(NotFoundError);
    expect(err.code).toBe("experiment_not_found");
    expect(err.message).toBe("Experiment 'nope' does not exist");
  });

  it("maps 429 to RateLimitError with Retry-After in ms and rate-limit headers", () => {
    const err = errorFromResponse(
      "POST",
      "/v1/assign",
      429,
      h({
        "retry-after": "7",
        "x-ratelimit-limit": "1000",
        "x-ratelimit-remaining": "0",
        "x-ratelimit-reset": "1760000000",
      }),
      { error: "rate_limited", message: "Too many requests" },
    );
    expect(err).toBeInstanceOf(RateLimitError);
    const rl = err as RateLimitError;
    expect(rl.retryAfterMs).toBe(7000);
    expect(rl.limit).toBe(1000);
    expect(rl.remaining).toBe(0);
    expect(rl.resetAt).toBe(1760000000);
  });

  it("maps 429 without headers to undefined fields", () => {
    const rl = errorFromResponse("POST", "/v1/assign", 429, h(), null) as RateLimitError;
    expect(rl.retryAfterMs).toBeUndefined();
    expect(rl.limit).toBeUndefined();
  });

  it("maps 503 to ServiceUnavailableError", () => {
    const err = errorFromResponse("POST", "/v1/events", 503, h(), {
      error: "service_unavailable",
      message: "Failed to enqueue event",
    });
    expect(err).toBeInstanceOf(ServiceUnavailableError);
  });

  it("maps any other status to ApiError with a generic message and the raw body", () => {
    const err = errorFromResponse("POST", "/v1/assign", 500, h(), "<html>oops</html>");
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(500);
    expect(err.message).toBe("POST /v1/assign failed with 500");
    expect(err.details).toBe("<html>oops</html>");
  });

  it("falls back to the generic message when the body has no message", () => {
    const err = errorFromResponse("POST", "/v1/assign", 400, h(), { error: "validation_error" });
    expect(err.message).toBe("POST /v1/assign failed with 400");
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run test/errors.test.ts`
Expected: FAIL — cannot resolve `../src/errors`.

- [ ] **Step 3: Create `sdk/javascript/src/errors.ts`**

```ts
export interface ErrorOptions {
  code?: string;
  status?: number;
  details?: unknown;
  cause?: unknown;
}

/** Base class for every error the SDK throws. Never thrown directly. */
export class ExperimentHubError extends Error {
  readonly code: string;
  readonly status?: number;
  readonly details?: unknown;

  constructor(message: string, options: ErrorOptions & { code: string }) {
    super(message, { cause: options.cause });
    this.name = new.target.name;
    this.code = options.code;
    this.status = options.status;
    this.details = options.details;
  }
}

/** Local pre-validation failure, or a server 400. */
export class ValidationError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "validation_error", status: 400, ...options });
  }
}

/** Server 401: missing or invalid API key. */
export class AuthenticationError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "unauthorized", status: 401, ...options });
  }
}

/** Server 404: unknown experiment or flag key. */
export class NotFoundError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "not_found", status: 404, ...options });
  }
}

/** Server 429. `retryAfterMs` is derived from the `Retry-After` header when present. */
export class RateLimitError extends ExperimentHubError {
  readonly retryAfterMs?: number;
  readonly limit?: number;
  readonly remaining?: number;
  readonly resetAt?: number;

  constructor(
    message: string,
    options: ErrorOptions & {
      retryAfterMs?: number;
      limit?: number;
      remaining?: number;
      resetAt?: number;
    } = {},
  ) {
    const { retryAfterMs, limit, remaining, resetAt, ...rest } = options;
    super(message, { code: "rate_limited", status: 429, ...rest });
    this.retryAfterMs = retryAfterMs;
    this.limit = limit;
    this.remaining = remaining;
    this.resetAt = resetAt;
  }
}

/** Server 503: the platform could not enqueue the request (e.g. Kafka down). */
export class ServiceUnavailableError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "service_unavailable", status: 503, ...options });
  }
}

/** `fetch` rejected, DNS failed, or the request timed out (`code: "timeout"`) or was aborted (`code: "aborted"`). */
export class NetworkError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "network_error", ...options });
  }
}

/** Any other non-2xx response. `details` holds the raw body. */
export class ApiError extends ExperimentHubError {
  constructor(message: string, options: ErrorOptions = {}) {
    super(message, { code: "api_error", ...options });
  }
}

interface ErrorBody {
  error?: unknown;
  message?: unknown;
  details?: unknown;
}

function asErrorBody(body: unknown): ErrorBody {
  return typeof body === "object" && body !== null ? (body as ErrorBody) : {};
}

function numberHeader(headers: Headers, name: string): number | undefined {
  const raw = headers.get(name);
  if (raw === null) return undefined;
  const n = Number(raw);
  return Number.isFinite(n) ? n : undefined;
}

/** Build the right error subclass for a non-2xx response. */
export function errorFromResponse(
  method: string,
  path: string,
  status: number,
  headers: Headers,
  body: unknown,
): ExperimentHubError {
  const parsed = asErrorBody(body);
  const message =
    typeof parsed.message === "string" && parsed.message.length > 0
      ? parsed.message
      : `${method} ${path} failed with ${status}`;
  // Only override the subclass default code when the server actually sent one:
  // spreading `{ code: undefined }` would clobber the default.
  const serverCode = typeof parsed.error === "string" ? parsed.error : undefined;
  const common: ErrorOptions = serverCode ? { code: serverCode, details: parsed.details } : { details: parsed.details };

  switch (status) {
    case 400:
      return new ValidationError(message, common);
    case 401:
      return new AuthenticationError(message, common);
    case 404:
      return new NotFoundError(message, common);
    case 429: {
      const retryAfterSeconds = numberHeader(headers, "retry-after");
      return new RateLimitError(message, {
        ...common,
        retryAfterMs: retryAfterSeconds === undefined ? undefined : retryAfterSeconds * 1000,
        limit: numberHeader(headers, "x-ratelimit-limit"),
        remaining: numberHeader(headers, "x-ratelimit-remaining"),
        resetAt: numberHeader(headers, "x-ratelimit-reset"),
      });
    }
    case 503:
      return new ServiceUnavailableError(message, common);
    default:
      return new ApiError(message, { ...common, status, details: body });
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run test/errors.test.ts`
Expected: PASS, 10 tests.

- [ ] **Step 5: Lint + typecheck, then commit**

Run: `npm run typecheck && npm run lint`

```bash
git add sdk/javascript/src/errors.ts sdk/javascript/test/errors.test.ts
git commit -m "feat(sdk-js): typed error hierarchy and response mapping

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Transport (headers, timeout, JSON, error mapping)

**Files:**

- Create: `sdk/javascript/src/transport.ts`, `sdk/javascript/test/helpers/fake-fetch.ts`
- Test: `sdk/javascript/test/transport.test.ts`

**Interfaces:**

- Consumes: `errorFromResponse`, `NetworkError` from Task 2.
- Produces: `interface Transport { post<T>(path: string, body: unknown, options?: RequestOptions): Promise<T> }`; `createTransport(config: TransportConfig): Transport` where `TransportConfig = { baseUrl: string; apiKey: string; timeoutMs: number; fetch: typeof globalThis.fetch; headers: Record<string,string> }`; `SDK_VERSION`. Test helper `fakeFetch(...responses): { fetch, requests }`.

- [ ] **Step 1: Create the test helper `sdk/javascript/test/helpers/fake-fetch.ts`**

```ts
export interface RecordedRequest {
  url: string;
  method: string;
  /** Lower-cased header names. */
  headers: Record<string, string>;
  body: unknown;
  signal: AbortSignal | undefined;
}

export interface ScriptedResponse {
  status?: number;
  headers?: Record<string, string>;
  /** Objects are JSON-encoded; strings are sent verbatim; undefined sends an empty body. */
  body?: unknown;
  /** Resolve only after this many ms (aborts early if the signal fires). */
  delayMs?: number;
}

/**
 * A `fetch` stand-in that records every request and replies with the scripted
 * responses in order. Once the script runs out it replies `200 {}`.
 */
export function fakeFetch(...script: ScriptedResponse[]) {
  const requests: RecordedRequest[] = [];
  const queue = [...script];

  const fetch: typeof globalThis.fetch = async (input, init) => {
    const planned = queue.shift() ?? { status: 200, body: {} };
    const headers: Record<string, string> = {};
    new Headers(init?.headers).forEach((value, key) => {
      headers[key.toLowerCase()] = value;
    });
    requests.push({
      url: typeof input === "string" ? input : input instanceof URL ? input.href : input.url,
      method: init?.method ?? "GET",
      headers,
      body: typeof init?.body === "string" && init.body.length > 0 ? JSON.parse(init.body) : undefined,
      signal: init?.signal ?? undefined,
    });

    if (planned.delayMs) {
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(resolve, planned.delayMs);
        init?.signal?.addEventListener(
          "abort",
          () => {
            clearTimeout(timer);
            reject(init.signal?.reason ?? new DOMException("The operation was aborted.", "AbortError"));
          },
          { once: true },
        );
      });
    }

    const body =
      planned.body === undefined
        ? ""
        : typeof planned.body === "string"
          ? planned.body
          : JSON.stringify(planned.body);
    return new Response(body, {
      status: planned.status ?? 200,
      headers: { "content-type": "application/json", ...planned.headers },
    });
  };

  return { fetch, requests };
}
```

- [ ] **Step 2: Write the failing tests `sdk/javascript/test/transport.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import { ApiError, NetworkError, NotFoundError, ValidationError } from "../src/errors";
import { SDK_VERSION, createTransport } from "../src/transport";
import { fakeFetch } from "./helpers/fake-fetch";

function transportWith(fetch: typeof globalThis.fetch, overrides: Partial<Parameters<typeof createTransport>[0]> = {}) {
  return createTransport({
    baseUrl: "http://hub.test",
    apiKey: "eh_live_secret",
    timeoutMs: 2000,
    fetch,
    headers: {},
    ...overrides,
  });
}

describe("transport.post", () => {
  it("POSTs JSON to baseUrl + path with auth and content headers", async () => {
    const { fetch, requests } = fakeFetch({ status: 200, body: { ok: true } });
    const result = await transportWith(fetch).post<{ ok: boolean }>("/v1/assign", { user_id: "u1" });

    expect(result).toEqual({ ok: true });
    expect(requests).toHaveLength(1);
    expect(requests[0].url).toBe("http://hub.test/v1/assign");
    expect(requests[0].method).toBe("POST");
    expect(requests[0].body).toEqual({ user_id: "u1" });
    expect(requests[0].headers["x-api-key"]).toBe("eh_live_secret");
    expect(requests[0].headers["content-type"]).toBe("application/json");
    expect(requests[0].headers["accept"]).toBe("application/json");
    expect(requests[0].headers["user-agent"]).toBe(`experiment-hub-sdk-js/${SDK_VERSION}`);
  });

  it("strips trailing slashes from baseUrl", async () => {
    const { fetch, requests } = fakeFetch();
    await transportWith(fetch, { baseUrl: "http://hub.test///" }).post("/v1/assign", {});
    expect(requests[0].url).toBe("http://hub.test/v1/assign");
  });

  it("merges extra headers, letting them override defaults except auth", async () => {
    const { fetch, requests } = fakeFetch();
    await transportWith(fetch, { headers: { "x-trace": "abc", "x-api-key": "spoof" } }).post("/p", {});
    expect(requests[0].headers["x-trace"]).toBe("abc");
    expect(requests[0].headers["x-api-key"]).toBe("eh_live_secret");
  });

  it("maps non-2xx responses through errorFromResponse", async () => {
    const { fetch } = fakeFetch(
      { status: 404, body: { error: "experiment_not_found", message: "nope" } },
      { status: 400, body: { error: "validation_error", message: "bad", details: [] } },
      { status: 500, body: "boom" },
    );
    const t = transportWith(fetch);
    await expect(t.post("/a", {})).rejects.toBeInstanceOf(NotFoundError);
    await expect(t.post("/b", {})).rejects.toBeInstanceOf(ValidationError);
    await expect(t.post("/c", {})).rejects.toBeInstanceOf(ApiError);
  });

  it("returns null for an empty 2xx body and raw text for non-JSON", async () => {
    const { fetch } = fakeFetch({ status: 202 }, { status: 200, body: "plain" });
    const t = transportWith(fetch);
    expect(await t.post("/a", {})).toBeNull();
    expect(await t.post("/b", {})).toBe("plain");
  });

  it("wraps a rejected fetch in NetworkError with cause", async () => {
    const cause = new TypeError("fetch failed");
    const fetch: typeof globalThis.fetch = async () => {
      throw cause;
    };
    const err = await transportWith(fetch).post("/a", {}).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("network_error");
    expect((err as NetworkError).cause).toBe(cause);
  });

  it("times out with NetworkError{code:'timeout'}", async () => {
    const { fetch } = fakeFetch({ delayMs: 200 });
    const err = await transportWith(fetch, { timeoutMs: 20 }).post("/slow", {}).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("timeout");
    expect((err as NetworkError).message).toContain("20 ms");
  });

  it("honours a caller-supplied AbortSignal", async () => {
    const { fetch } = fakeFetch({ delayMs: 200 });
    const controller = new AbortController();
    const pending = transportWith(fetch).post("/slow", {}, { signal: controller.signal });
    controller.abort();
    const err = await pending.catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("aborted");
  });
});
```

- [ ] **Step 3: Run to verify it fails**

Run: `npx vitest run test/transport.test.ts`
Expected: FAIL — cannot resolve `../src/transport`.

- [ ] **Step 4: Create `sdk/javascript/src/transport.ts`**

```ts
import { NetworkError, errorFromResponse } from "./errors";
import type { RequestOptions } from "./types";

export const SDK_VERSION = "0.1.0";

export interface TransportConfig {
  baseUrl: string;
  apiKey: string;
  timeoutMs: number;
  fetch: typeof globalThis.fetch;
  headers: Record<string, string>;
}

export interface Transport {
  post<T>(path: string, body: unknown, options?: RequestOptions): Promise<T>;
}

const TIMEOUT = Symbol("experiment-hub-sdk-timeout");

const isNode = typeof process !== "undefined" && Boolean(process.versions?.node);

async function parseBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (text.length === 0) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return text;
  }
}

function describe(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

export function createTransport(config: TransportConfig): Transport {
  const base = config.baseUrl.replace(/\/+$/, "");

  const baseHeaders: Record<string, string> = {
    "content-type": "application/json",
    accept: "application/json",
    ...(isNode ? { "user-agent": `experiment-hub-sdk-js/${SDK_VERSION}` } : {}),
  };
  for (const [key, value] of Object.entries(config.headers)) {
    if (key.toLowerCase() === "x-api-key") continue; // the configured key always wins
    baseHeaders[key.toLowerCase()] = value;
  }
  baseHeaders["x-api-key"] = config.apiKey;

  return {
    async post<T>(path: string, body: unknown, options: RequestOptions = {}): Promise<T> {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(TIMEOUT), config.timeoutMs);
      const forwardAbort = () => controller.abort(options.signal?.reason);
      if (options.signal?.aborted) forwardAbort();
      options.signal?.addEventListener("abort", forwardAbort, { once: true });

      let response: Response;
      try {
        response = await config.fetch(base + path, {
          method: "POST",
          headers: baseHeaders,
          body: JSON.stringify(body),
          signal: controller.signal,
        });
      } catch (cause) {
        if (controller.signal.aborted && controller.signal.reason === TIMEOUT) {
          throw new NetworkError(`POST ${path} timed out after ${config.timeoutMs} ms`, {
            code: "timeout",
            cause,
          });
        }
        if (controller.signal.aborted) {
          throw new NetworkError(`POST ${path} was aborted`, { code: "aborted", cause });
        }
        throw new NetworkError(`POST ${path} failed: ${describe(cause)}`, { cause });
      } finally {
        clearTimeout(timer);
        options.signal?.removeEventListener("abort", forwardAbort);
      }

      const parsed = await parseBody(response);
      if (!response.ok) {
        throw errorFromResponse("POST", path, response.status, response.headers, parsed);
      }
      return parsed as T;
    },
  };
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `npx vitest run test/transport.test.ts`
Expected: PASS, 8 tests. If the "aborted" test sees `code: "timeout"`, the caller's abort fired after the timer — it can't, since timeoutMs is 2000; re-check that `forwardAbort` passes `options.signal.reason` (undefined is fine; the branch only checks `=== TIMEOUT`).

- [ ] **Step 6: Lint + typecheck, then commit**

Run: `npm run typecheck && npm run lint`

```bash
git add sdk/javascript/src/transport.ts sdk/javascript/test/helpers/fake-fetch.ts sdk/javascript/test/transport.test.ts
git commit -m "feat(sdk-js): transport with timeout, abort, and typed error mapping

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Assignment methods

**Files:**

- Create: `sdk/javascript/src/assign.ts`
- Test: `sdk/javascript/test/assign.test.ts`

**Interfaces:**

- Consumes: `Transport` (Task 3); types `AssignInput`, `Assignment`, `AssignBatchInput`, `BatchAssignment`, `RequestOptions` (Task 1).
- Produces: `createAssignMethods(transport: Transport): { assign, assignBatch }` with the signatures from `ExperimentHubClient`.

- [ ] **Step 1: Write the failing tests `sdk/javascript/test/assign.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import { createAssignMethods } from "../src/assign";
import { NotFoundError } from "../src/errors";
import { createTransport } from "../src/transport";
import { fakeFetch } from "./helpers/fake-fetch";

const wireAssignment = {
  experiment_key: "checkout-copy-demo",
  variant_key: "treatment",
  variant_name: "Treatment",
  experiment_id: "exp-1",
  variant_id: "var-2",
  is_control: false,
  enrolled: true,
  assigned_at: "2026-10-07T10:00:00Z",
};

function setup(...responses: Parameters<typeof fakeFetch>) {
  const { fetch, requests } = fakeFetch(...responses);
  const transport = createTransport({ baseUrl: "http://hub.test", apiKey: "k", timeoutMs: 2000, fetch, headers: {} });
  return { methods: createAssignMethods(transport), requests };
}

describe("assign", () => {
  it("posts the snake_case wire body and maps the response to camelCase", async () => {
    const { methods, requests } = setup({ status: 200, body: wireAssignment });
    const result = await methods.assign({
      userId: "u1",
      experimentKey: "checkout-copy-demo",
      attributes: { country: "IN" },
    });

    expect(requests[0].url).toBe("http://hub.test/v1/assign");
    expect(requests[0].body).toEqual({
      user_id: "u1",
      experiment_key: "checkout-copy-demo",
      attributes: { country: "IN" },
    });
    expect(result).toEqual({
      experimentKey: "checkout-copy-demo",
      variantKey: "treatment",
      variantName: "Treatment",
      experimentId: "exp-1",
      variantId: "var-2",
      isControl: false,
      enrolled: true,
      assignedAt: "2026-10-07T10:00:00Z",
    });
  });

  it("sends an empty attributes object when none are given", async () => {
    const { methods, requests } = setup({ status: 200, body: wireAssignment });
    await methods.assign({ userId: "u1", experimentKey: "checkout-copy-demo" });
    expect(requests[0].body).toEqual({ user_id: "u1", experiment_key: "checkout-copy-demo", attributes: {} });
  });

  it("passes enrolled:false through untouched", async () => {
    const { methods } = setup({ status: 200, body: { ...wireAssignment, enrolled: false, is_control: true } });
    const result = await methods.assign({ userId: "u1", experimentKey: "pricing-layout-demo" });
    expect(result.enrolled).toBe(false);
    expect(result.isControl).toBe(true);
  });

  it("throws NotFoundError for an unknown experiment", async () => {
    const { methods } = setup({
      status: 404,
      body: { error: "experiment_not_found", message: "Experiment 'nope' does not exist" },
    });
    await expect(methods.assign({ userId: "u1", experimentKey: "nope" })).rejects.toBeInstanceOf(NotFoundError);
  });

  it("forwards the abort signal", async () => {
    const { methods, requests } = setup({ status: 200, body: wireAssignment });
    const controller = new AbortController();
    await methods.assign({ userId: "u1", experimentKey: "x" }, { signal: controller.signal });
    expect(requests[0].signal).toBeDefined();
  });
});

describe("assignBatch", () => {
  it("posts experiment_keys and maps items and per-item errors", async () => {
    const { methods, requests } = setup({
      status: 200,
      body: {
        user_id: "u1",
        assigned_at: "2026-10-07T10:00:00Z",
        assignments: [
          {
            experiment_key: "checkout-copy-demo",
            variant_key: "control",
            experiment_id: "exp-1",
            variant_id: "var-1",
            is_control: true,
            enrolled: true,
          },
          { experiment_key: "nope", error: "experiment_not_found" },
        ],
      },
    });
    const result = await methods.assignBatch({ userId: "u1", experimentKeys: ["checkout-copy-demo", "nope"] });

    expect(requests[0].url).toBe("http://hub.test/v1/assign/batch");
    expect(requests[0].body).toEqual({ user_id: "u1", experiment_keys: ["checkout-copy-demo", "nope"], attributes: {} });
    expect(result).toEqual({
      userId: "u1",
      assignedAt: "2026-10-07T10:00:00Z",
      assignments: [
        {
          experimentKey: "checkout-copy-demo",
          variantKey: "control",
          experimentId: "exp-1",
          variantId: "var-1",
          isControl: true,
          enrolled: true,
        },
        { experimentKey: "nope", error: "experiment_not_found" },
      ],
    });
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run test/assign.test.ts`
Expected: FAIL — cannot resolve `../src/assign`.

- [ ] **Step 3: Create `sdk/javascript/src/assign.ts`**

```ts
import type { Transport } from "./transport";
import type {
  AssignBatchInput,
  AssignInput,
  Assignment,
  BatchAssignment,
  BatchAssignmentError,
  BatchAssignmentItem,
  RequestOptions,
} from "./types";

interface WireAssignment {
  experiment_key: string;
  experiment_id: string;
  variant_key: string;
  variant_id: string;
  variant_name: string;
  is_control: boolean;
  enrolled: boolean;
  assigned_at: string;
}

type WireBatchItem =
  | {
      experiment_key: string;
      experiment_id: string;
      variant_key: string;
      variant_id: string;
      is_control: boolean;
      enrolled: boolean;
    }
  | { experiment_key: string; error: string };

interface WireBatchAssignment {
  user_id: string;
  assigned_at: string;
  assignments: WireBatchItem[];
}

function fromWireAssignment(raw: WireAssignment): Assignment {
  return {
    experimentKey: raw.experiment_key,
    experimentId: raw.experiment_id,
    variantKey: raw.variant_key,
    variantId: raw.variant_id,
    variantName: raw.variant_name,
    isControl: raw.is_control,
    enrolled: raw.enrolled,
    assignedAt: raw.assigned_at,
  };
}

function fromWireBatchItem(raw: WireBatchItem): BatchAssignmentItem | BatchAssignmentError {
  if ("error" in raw) {
    return { experimentKey: raw.experiment_key, error: raw.error };
  }
  return {
    experimentKey: raw.experiment_key,
    experimentId: raw.experiment_id,
    variantKey: raw.variant_key,
    variantId: raw.variant_id,
    isControl: raw.is_control,
    enrolled: raw.enrolled,
  };
}

export function createAssignMethods(transport: Transport) {
  return {
    async assign(input: AssignInput, options?: RequestOptions): Promise<Assignment> {
      const raw = await transport.post<WireAssignment>(
        "/v1/assign",
        { user_id: input.userId, experiment_key: input.experimentKey, attributes: input.attributes ?? {} },
        options,
      );
      return fromWireAssignment(raw);
    },

    async assignBatch(input: AssignBatchInput, options?: RequestOptions): Promise<BatchAssignment> {
      const raw = await transport.post<WireBatchAssignment>(
        "/v1/assign/batch",
        { user_id: input.userId, experiment_keys: input.experimentKeys, attributes: input.attributes ?? {} },
        options,
      );
      return {
        userId: raw.user_id,
        assignedAt: raw.assigned_at,
        assignments: raw.assignments.map(fromWireBatchItem),
      };
    },
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run test/assign.test.ts`
Expected: PASS, 6 tests.

- [ ] **Step 5: Lint + typecheck, then commit**

```bash
git add sdk/javascript/src/assign.ts sdk/javascript/test/assign.test.ts
git commit -m "feat(sdk-js): assign and assignBatch

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Event methods with local pre-validation and defaults

**Files:**

- Create: `sdk/javascript/src/events.ts`
- Test: `sdk/javascript/test/events.test.ts`

**Interfaces:**

- Consumes: `Transport` (Task 3); `ValidationError` (Task 2); types `TrackInput`, `EventReceipt`, `BatchEventReceipt`, `RequestOptions` (Task 1).
- Produces: `createEventMethods(transport): { track, trackBatch }`; `toWireEvent(input: TrackInput, index?: number): WireEvent` (exported for the contract test's "mirror the server" check).

- [ ] **Step 1: Write the failing tests `sdk/javascript/test/events.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import { ValidationError } from "../src/errors";
import { createEventMethods, toWireEvent } from "../src/events";
import { createTransport } from "../src/transport";
import { fakeFetch } from "./helpers/fake-fetch";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function setup(...responses: Parameters<typeof fakeFetch>) {
  const { fetch, requests } = fakeFetch(...responses);
  const transport = createTransport({ baseUrl: "http://hub.test", apiKey: "k", timeoutMs: 2000, fetch, headers: {} });
  return { methods: createEventMethods(transport), requests };
}

const accepted = { status: "accepted", event_id: "evt-1", received_at: "2026-10-07T10:00:00Z" };

describe("toWireEvent", () => {
  it("maps fields and fills timestamp + idempotency_key when absent", () => {
    const before = Date.now();
    const wire = toWireEvent({ userId: "u1", type: "conversion", name: "checkout_completed" });
    expect(wire.user_id).toBe("u1");
    expect(wire.event_type).toBe("conversion");
    expect(wire.event_name).toBe("checkout_completed");
    expect(wire.idempotency_key).toMatch(UUID_RE);
    expect(Date.parse(wire.timestamp)).toBeGreaterThanOrEqual(before - 1);
    expect(wire).not.toHaveProperty("value");
    expect(wire).not.toHaveProperty("properties");
  });

  it("keeps caller-supplied timestamp (Date or string) and idempotency key", () => {
    const asDate = toWireEvent({
      userId: "u1",
      type: "revenue",
      name: "order_completed",
      value: 42.5,
      timestamp: new Date("2026-01-02T03:04:05.000Z"),
      idempotencyKey: "order-123",
      properties: { currency: "INR" },
    });
    expect(asDate.timestamp).toBe("2026-01-02T03:04:05.000Z");
    expect(asDate.idempotency_key).toBe("order-123");
    expect(asDate.value).toBe(42.5);
    expect(asDate.properties).toEqual({ currency: "INR" });

    const asString = toWireEvent({ userId: "u1", type: "conversion", name: "x", timestamp: "2026-01-02T03:04:05Z" });
    expect(asString.timestamp).toBe("2026-01-02T03:04:05Z");
  });

  it.each([
    [{ userId: "", type: "conversion", name: "x" }, "user_id"],
    [{ userId: "u", type: "conversion", name: "" }, "event_name"],
    [{ userId: "u", type: "click", name: "x" }, "event_type"],
    [{ userId: "u", type: "metric", name: "x" }, "value"],
    [{ userId: "u", type: "revenue", name: "x" }, "value"],
  ] as const)("rejects %j with a ValidationError on field %s", (input, field) => {
    let caught: unknown;
    try {
      toWireEvent(input as never);
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(ValidationError);
    expect((caught as ValidationError).details).toEqual([expect.objectContaining({ field })]);
  });
});

describe("track", () => {
  it("posts one event and maps the receipt", async () => {
    const { methods, requests } = setup({ status: 202, body: accepted });
    const receipt = await methods.track({ userId: "u1", type: "conversion", name: "checkout_completed" });
    expect(requests[0].url).toBe("http://hub.test/v1/events");
    expect(requests[0].body).toMatchObject({ user_id: "u1", event_type: "conversion", event_name: "checkout_completed" });
    expect(receipt).toEqual({ status: "accepted", eventId: "evt-1", receivedAt: "2026-10-07T10:00:00Z" });
  });

  it("does not call fetch when local validation fails", async () => {
    const { methods, requests } = setup();
    await expect(methods.track({ userId: "u1", type: "metric", name: "x" })).rejects.toBeInstanceOf(ValidationError);
    expect(requests).toHaveLength(0);
  });
});

describe("trackBatch", () => {
  it("posts { events } and maps a partial receipt", async () => {
    const { methods, requests } = setup({
      status: 207,
      body: {
        status: "partial",
        accepted: 1,
        rejected: 1,
        errors: [{ index: 1, error: "validation_error", details: [{ field: "timestamp", error: "must be a valid ISO 8601 timestamp" }] }],
      },
    });
    const receipt = await methods.trackBatch([
      { userId: "u1", type: "conversion", name: "a" },
      { userId: "u2", type: "conversion", name: "b", timestamp: "2026-01-01T00:00:00Z" },
    ]);
    expect(requests[0].url).toBe("http://hub.test/v1/events/batch");
    expect((requests[0].body as { events: unknown[] }).events).toHaveLength(2);
    expect(receipt).toEqual({
      status: "partial",
      accepted: 1,
      rejected: 1,
      errors: [{ index: 1, error: "validation_error", details: [{ field: "timestamp", error: "must be a valid ISO 8601 timestamp" }] }],
    });
  });

  it("rejects an empty batch and a batch over 1000 locally", async () => {
    const { methods, requests } = setup();
    await expect(methods.trackBatch([])).rejects.toBeInstanceOf(ValidationError);
    const tooMany = Array.from({ length: 1001 }, () => ({ userId: "u", type: "conversion" as const, name: "x" }));
    await expect(methods.trackBatch(tooMany)).rejects.toBeInstanceOf(ValidationError);
    expect(requests).toHaveLength(0);
  });

  it("reports the failing index in local validation errors", async () => {
    const { methods } = setup();
    const err = await methods
      .trackBatch([
        { userId: "u", type: "conversion", name: "ok" },
        { userId: "u", type: "metric", name: "no-value" },
      ])
      .catch((e: unknown) => e);
    expect(err).toBeInstanceOf(ValidationError);
    expect((err as ValidationError).message).toContain("events[1]");
  });

  it("throws ValidationError when the server rejects every event (400)", async () => {
    const { methods } = setup({
      status: 400,
      body: { status: "rejected", accepted: 0, rejected: 1, errors: [{ index: 0, error: "validation_error", details: [] }] },
    });
    await expect(methods.trackBatch([{ userId: "u", type: "conversion", name: "x" }])).rejects.toBeInstanceOf(ValidationError);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run test/events.test.ts`
Expected: FAIL — cannot resolve `../src/events`.

- [ ] **Step 3: Create `sdk/javascript/src/events.ts`**

```ts
import { ValidationError } from "./errors";
import type { Transport } from "./transport";
import type { BatchEventReceipt, EventReceipt, EventType, RequestOptions, TrackInput } from "./types";

export interface WireEvent {
  user_id: string;
  event_type: EventType;
  event_name: string;
  timestamp: string;
  idempotency_key: string;
  value?: number;
  properties?: Record<string, unknown>;
}

interface WireEventReceipt {
  status: "accepted";
  event_id: string;
  received_at: string;
}

const EVENT_TYPES: ReadonlySet<string> = new Set<EventType>(["conversion", "metric", "revenue"]);
const MAX_BATCH = 1000;

function fail(where: string, field: string, error: string): never {
  throw new ValidationError(`${where}: ${field} ${error}`, { details: [{ field, error }] });
}

/**
 * Validate one event and convert it to the server's wire shape, filling in
 * `timestamp` (now) and `idempotency_key` (random UUID) when absent.
 * `where` labels the failing input in error messages (`event` or `events[3]`).
 */
export function toWireEvent(input: TrackInput, index?: number): WireEvent {
  const where = index === undefined ? "event" : `events[${index}]`;

  if (typeof input.userId !== "string" || input.userId.length === 0) fail(where, "user_id", "is required");
  if (typeof input.name !== "string" || input.name.length === 0) fail(where, "event_name", "is required");
  if (!EVENT_TYPES.has(input.type)) fail(where, "event_type", "must be one of: conversion, metric, revenue");
  if ((input.type === "metric" || input.type === "revenue") && typeof input.value !== "number") {
    fail(where, "value", `is required for ${input.type} events`);
  }

  const timestamp =
    input.timestamp === undefined
      ? new Date().toISOString()
      : input.timestamp instanceof Date
        ? input.timestamp.toISOString()
        : input.timestamp;

  const wire: WireEvent = {
    user_id: input.userId,
    event_type: input.type,
    event_name: input.name,
    timestamp,
    idempotency_key: input.idempotencyKey ?? crypto.randomUUID(),
  };
  if (input.value !== undefined) wire.value = input.value;
  if (input.properties !== undefined) wire.properties = input.properties;
  return wire;
}

export function createEventMethods(transport: Transport) {
  return {
    async track(event: TrackInput, options?: RequestOptions): Promise<EventReceipt> {
      const wire = toWireEvent(event);
      const raw = await transport.post<WireEventReceipt>("/v1/events", wire, options);
      return { status: raw.status, eventId: raw.event_id, receivedAt: raw.received_at };
    },

    async trackBatch(events: TrackInput[], options?: RequestOptions): Promise<BatchEventReceipt> {
      if (!Array.isArray(events) || events.length === 0) fail("events", "events", "must be a non-empty array");
      if (events.length > MAX_BATCH) fail("events", "events", `must contain at most ${MAX_BATCH} events`);
      const wire = events.map((event, index) => toWireEvent(event, index));
      // 202 (all accepted) and 207 (partial) both resolve; 400 (all rejected) throws via transport.
      return transport.post<BatchEventReceipt>("/v1/events/batch", { events: wire }, options);
    },
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run test/events.test.ts`
Expected: PASS, 10 tests. The batch receipt body from the server is already in the public shape (`status`, `accepted`, `rejected`, `errors[{index,error,details}]`), so no mapping is needed — the test asserts deep equality to confirm.

- [ ] **Step 5: Lint + typecheck, then commit**

```bash
git add sdk/javascript/src/events.ts sdk/javascript/test/events.test.ts
git commit -m "feat(sdk-js): track and trackBatch with local validation and defaults

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Feature flag methods

**Files:**

- Create: `sdk/javascript/src/flags.ts`
- Test: `sdk/javascript/test/flags.test.ts`

**Interfaces:**

- Consumes: `Transport` (Task 3); types `FlagEvaluateInput`, `FlagEvaluateBatchInput`, `FlagEvaluation`, `RequestOptions` (Task 1).
- Produces: `createFlagMethods(transport): { evaluate, evaluateBatch }`.

- [ ] **Step 1: Write the failing tests `sdk/javascript/test/flags.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import { NotFoundError } from "../src/errors";
import { createFlagMethods } from "../src/flags";
import { createTransport } from "../src/transport";
import { fakeFetch } from "./helpers/fake-fetch";

function setup(...responses: Parameters<typeof fakeFetch>) {
  const { fetch, requests } = fakeFetch(...responses);
  const transport = createTransport({ baseUrl: "http://hub.test", apiKey: "k", timeoutMs: 2000, fetch, headers: {} });
  return { flags: createFlagMethods(transport), requests };
}

describe("flags.evaluate", () => {
  it("posts key + context and returns { key, enabled }", async () => {
    const { flags, requests } = setup({ status: 200, body: { key: "checkout_reassurance", enabled: true } });
    const result = await flags.evaluate({ key: "checkout_reassurance", context: { user_id: "u1" } });
    expect(requests[0].url).toBe("http://hub.test/api/v1/flags/evaluate");
    expect(requests[0].body).toEqual({ key: "checkout_reassurance", context: { user_id: "u1" } });
    expect(result).toEqual({ key: "checkout_reassurance", enabled: true });
  });

  it("defaults context to {}", async () => {
    const { flags, requests } = setup({ status: 200, body: { key: "k", enabled: false } });
    await flags.evaluate({ key: "k" });
    expect(requests[0].body).toEqual({ key: "k", context: {} });
  });

  it("throws NotFoundError on 404", async () => {
    const { flags } = setup({ status: 404, body: { error: "not_found" } });
    await expect(flags.evaluate({ key: "missing" })).rejects.toBeInstanceOf(NotFoundError);
  });
});

describe("flags.evaluateBatch", () => {
  it("posts keys + context and unwraps data", async () => {
    const { flags, requests } = setup({
      status: 200,
      body: { data: [{ key: "a", enabled: true }, { key: "b", enabled: false }] },
    });
    const result = await flags.evaluateBatch({ keys: ["a", "b"] });
    expect(requests[0].url).toBe("http://hub.test/api/v1/flags/evaluate/batch");
    expect(requests[0].body).toEqual({ keys: ["a", "b"], context: {} });
    expect(result).toEqual([{ key: "a", enabled: true }, { key: "b", enabled: false }]);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run test/flags.test.ts`
Expected: FAIL — cannot resolve `../src/flags`.

- [ ] **Step 3: Create `sdk/javascript/src/flags.ts`**

```ts
import type { Transport } from "./transport";
import type { FlagEvaluateBatchInput, FlagEvaluateInput, FlagEvaluation, RequestOptions } from "./types";

export function createFlagMethods(transport: Transport) {
  return {
    async evaluate(input: FlagEvaluateInput, options?: RequestOptions): Promise<FlagEvaluation> {
      return transport.post<FlagEvaluation>(
        "/api/v1/flags/evaluate",
        { key: input.key, context: input.context ?? {} },
        options,
      );
    },

    async evaluateBatch(input: FlagEvaluateBatchInput, options?: RequestOptions): Promise<FlagEvaluation[]> {
      const raw = await transport.post<{ data: FlagEvaluation[] }>(
        "/api/v1/flags/evaluate/batch",
        { keys: input.keys, context: input.context ?? {} },
        options,
      );
      return raw.data;
    },
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run test/flags.test.ts`
Expected: PASS, 4 tests.

- [ ] **Step 5: Lint + typecheck, then commit**

```bash
git add sdk/javascript/src/flags.ts sdk/javascript/test/flags.test.ts
git commit -m "feat(sdk-js): feature flag evaluation

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: `createClient` and the public entry point

**Files:**

- Create: `sdk/javascript/src/client.ts`
- Modify: `sdk/javascript/src/index.ts` (replace the Task 1 placeholder)
- Test: `sdk/javascript/test/client.test.ts`; update `sdk/javascript/test/index.test.ts`

**Interfaces:**

- Consumes: Tasks 2–6.
- Produces: `createClient(config: ClientConfig): ExperimentHubClient`; package root exports `createClient`, `SDK_VERSION`, every error class, every type, `isBatchAssignmentError`.

- [ ] **Step 1: Write the failing tests `sdk/javascript/test/client.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import { createClient } from "../src/client";
import { ValidationError } from "../src/errors";
import { fakeFetch } from "./helpers/fake-fetch";

describe("createClient", () => {
  it("requires baseUrl and apiKey", () => {
    expect(() => createClient({ baseUrl: "", apiKey: "k" })).toThrow(ValidationError);
    expect(() => createClient({ baseUrl: "http://hub.test", apiKey: "" })).toThrow(ValidationError);
  });

  it("uses the injected fetch and default timeout of 2000 ms", async () => {
    const { fetch, requests } = fakeFetch({ status: 200, body: { key: "k", enabled: true } });
    const hub = createClient({ baseUrl: "http://hub.test/", apiKey: "eh_live_x", fetch });
    await hub.flags.evaluate({ key: "k" });
    expect(requests[0].url).toBe("http://hub.test/api/v1/flags/evaluate");
    expect(requests[0].headers["x-api-key"]).toBe("eh_live_x");
  });

  it("exposes all method groups", () => {
    const hub = createClient({ baseUrl: "http://hub.test", apiKey: "k", fetch: fakeFetch().fetch });
    expect(typeof hub.assign).toBe("function");
    expect(typeof hub.assignBatch).toBe("function");
    expect(typeof hub.track).toBe("function");
    expect(typeof hub.trackBatch).toBe("function");
    expect(typeof hub.flags.evaluate).toBe("function");
    expect(typeof hub.flags.evaluateBatch).toBe("function");
  });

  it("two clients do not share state", async () => {
    const a = fakeFetch({ status: 200, body: { key: "k", enabled: true } });
    const b = fakeFetch({ status: 200, body: { key: "k", enabled: false } });
    const hubA = createClient({ baseUrl: "http://a.test", apiKey: "key-a", fetch: a.fetch });
    const hubB = createClient({ baseUrl: "http://b.test", apiKey: "key-b", fetch: b.fetch });
    await hubA.flags.evaluate({ key: "k" });
    await hubB.flags.evaluate({ key: "k" });
    expect(a.requests[0].headers["x-api-key"]).toBe("key-a");
    expect(b.requests[0].headers["x-api-key"]).toBe("key-b");
  });

  it("throws a config error when no fetch is available", () => {
    const original = globalThis.fetch;
    // @ts-expect-error simulate a runtime without fetch
    globalThis.fetch = undefined;
    try {
      expect(() => createClient({ baseUrl: "http://hub.test", apiKey: "k" })).toThrow(/fetch/);
    } finally {
      globalThis.fetch = original;
    }
  });
});
```

Replace `sdk/javascript/test/index.test.ts` with:

```ts
import { describe, expect, it } from "vitest";
import * as sdk from "../src/index";

describe("public entry point", () => {
  it("exports the factory, version, and error classes", () => {
    expect(sdk.SDK_VERSION).toBe("0.1.0");
    expect(typeof sdk.createClient).toBe("function");
    expect(typeof sdk.isBatchAssignmentError).toBe("function");
    for (const name of [
      "ExperimentHubError",
      "ValidationError",
      "AuthenticationError",
      "NotFoundError",
      "RateLimitError",
      "ServiceUnavailableError",
      "NetworkError",
      "ApiError",
    ] as const) {
      expect(typeof sdk[name]).toBe("function");
    }
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run test/client.test.ts test/index.test.ts`
Expected: FAIL — cannot resolve `../src/client`; `sdk.createClient` undefined.

- [ ] **Step 3: Create `sdk/javascript/src/client.ts`**

```ts
import { createAssignMethods } from "./assign";
import { ValidationError } from "./errors";
import { createEventMethods } from "./events";
import { createFlagMethods } from "./flags";
import { createTransport } from "./transport";
import type { ClientConfig, ExperimentHubClient } from "./types";

const DEFAULT_TIMEOUT_MS = 2000;

/**
 * Create an ExperimentHub client. Pure: no global state, safe to call many
 * times with different keys.
 */
export function createClient(config: ClientConfig): ExperimentHubClient {
  if (typeof config.baseUrl !== "string" || config.baseUrl.length === 0) {
    throw new ValidationError("createClient: baseUrl is required", {
      code: "config_error",
      details: [{ field: "baseUrl", error: "is required" }],
    });
  }
  if (typeof config.apiKey !== "string" || config.apiKey.length === 0) {
    throw new ValidationError("createClient: apiKey is required", {
      code: "config_error",
      details: [{ field: "apiKey", error: "is required" }],
    });
  }
  const fetchImpl = config.fetch ?? globalThis.fetch;
  if (typeof fetchImpl !== "function") {
    throw new ValidationError("createClient: no fetch available; pass config.fetch", {
      code: "config_error",
      details: [{ field: "fetch", error: "is required on runtimes without global fetch" }],
    });
  }

  const transport = createTransport({
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    timeoutMs: config.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    fetch: config.fetch ?? fetchImpl.bind(globalThis),
    headers: config.headers ?? {},
  });

  const { assign, assignBatch } = createAssignMethods(transport);
  const { track, trackBatch } = createEventMethods(transport);
  const flags = createFlagMethods(transport);

  return { assign, assignBatch, track, trackBatch, flags };
}
```

- [ ] **Step 4: Replace `sdk/javascript/src/index.ts`**

```ts
export { createClient } from "./client";
export { SDK_VERSION } from "./transport";
export {
  ApiError,
  AuthenticationError,
  ExperimentHubError,
  NetworkError,
  NotFoundError,
  RateLimitError,
  ServiceUnavailableError,
  ValidationError,
} from "./errors";
export type { ErrorOptions } from "./errors";
export { isBatchAssignmentError } from "./types";
export type {
  AssignBatchInput,
  AssignInput,
  Assignment,
  Attributes,
  BatchAssignment,
  BatchAssignmentError,
  BatchAssignmentItem,
  BatchEventError,
  BatchEventReceipt,
  ClientConfig,
  EventReceipt,
  EventType,
  ExperimentHubClient,
  FlagEvaluateBatchInput,
  FlagEvaluateInput,
  FlagEvaluation,
  RequestOptions,
  TrackInput,
} from "./types";
```

- [ ] **Step 5: Run the whole check**

Run: `npm run check`
Expected: typecheck clean, lint clean, all unit tests pass (index 1, errors 10, transport 8, assign 6, events 10, flags 4, client 5 = 44), build emits `dist/`. Then confirm the built artefact loads in both module systems:

```bash
node -e "import('./dist/index.js').then(m => console.log('esm', typeof m.createClient))"
node -e "console.log('cjs', typeof require('./dist/index.cjs').createClient)"
```

Expected: `esm function` and `cjs function`.

- [ ] **Step 6: Commit**

```bash
git add sdk/javascript/src/client.ts sdk/javascript/src/index.ts sdk/javascript/test/client.test.ts sdk/javascript/test/index.test.ts
git commit -m "feat(sdk-js): createClient and public entry point

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Live contract suite (and the flags `current_scope` probe)

**Files:**

- Create: `sdk/javascript/test/contract/live.contract.test.ts`
- Possibly modify: `apps/experiment_hub_web/lib/experiment_hub_web/controllers/feature_flag_controller.ex:49-67` (only if the probe fails — see Step 4)

**Interfaces:**

- Consumes: the whole public API (Task 7), `toWireEvent` (Task 5).
- Requires a running local stack: `docker compose up -d`, `mix ecto.migrate`, `mix dev.demo` (prints the API key), `mix phx.server`. See `.claude/skills/run-stack/SKILL.md`.

- [ ] **Step 1: Write `sdk/javascript/test/contract/live.contract.test.ts`**

```ts
import { describe, expect, it } from "vitest";
import {
  AuthenticationError,
  NotFoundError,
  ValidationError,
  createClient,
  isBatchAssignmentError,
} from "../../src/index";
import { toWireEvent } from "../../src/events";

const BASE_URL = process.env.EXPERIMENT_HUB_BASE_URL;
const API_KEY = process.env.EXPERIMENT_HUB_API_KEY;
const enabled = Boolean(BASE_URL && API_KEY);

// Seeded by `mix dev.demo` (apps/experiment_hub/lib/experiment_hub/demo_seeds.ex).
const RUNNING = "checkout-copy-demo";
const PAUSED = "pricing-layout-demo";
const FLAG = "checkout_reassurance";
const CONVERSION_EVENT = "checkout_completed";

const userId = () => `sdk-contract-${crypto.randomUUID()}`;

describe.skipIf(!enabled)("live contract against ExperimentHub", () => {
  const hub = createClient({ baseUrl: BASE_URL ?? "", apiKey: API_KEY ?? "" });

  it("assigns a running experiment and is sticky per user", async () => {
    const uid = userId();
    const first = await hub.assign({ userId: uid, experimentKey: RUNNING });
    expect(first.enrolled).toBe(true);
    expect(first.experimentKey).toBe(RUNNING);
    expect(["control", "treatment"]).toContain(first.variantKey);
    expect(first.isControl).toBe(first.variantKey === "control");

    const second = await hub.assign({ userId: uid, experimentKey: RUNNING });
    expect(second.variantKey).toBe(first.variantKey);
    expect(second.variantId).toBe(first.variantId);
  });

  it("returns control with enrolled:false for a paused experiment", async () => {
    const result = await hub.assign({ userId: userId(), experimentKey: PAUSED });
    expect(result.enrolled).toBe(false);
    expect(result.isControl).toBe(true);
  });

  it("throws NotFoundError for an unknown experiment", async () => {
    await expect(hub.assign({ userId: userId(), experimentKey: "does-not-exist" })).rejects.toBeInstanceOf(
      NotFoundError,
    );
  });

  it("assignBatch returns one assignment and one per-item error", async () => {
    const result = await hub.assignBatch({ userId: userId(), experimentKeys: [RUNNING, "does-not-exist"] });
    expect(result.assignments).toHaveLength(2);
    const [good, bad] = result.assignments;
    expect(isBatchAssignmentError(good)).toBe(false);
    expect(isBatchAssignmentError(bad)).toBe(true);
    if (isBatchAssignmentError(bad)) expect(bad.error).toMatch(/not_found/);
  });

  it("tracks a conversion event", async () => {
    const receipt = await hub.track({ userId: userId(), type: "conversion", name: CONVERSION_EVENT });
    expect(receipt.status).toBe("accepted");
    expect(receipt.eventId).toMatch(/[0-9a-f-]{36}/);
  });

  it("local validation mirrors the server: metric without value is rejected by both", async () => {
    const input = { userId: userId(), type: "metric" as const, name: "anything" };
    await expect(hub.track(input)).rejects.toBeInstanceOf(ValidationError);

    // Bypass local validation to prove the server enforces the same rule.
    const wire = { ...toWireEvent({ ...input, value: 1 }) };
    delete (wire as { value?: number }).value;
    const response = await fetch(`${BASE_URL}/v1/events`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-api-key": API_KEY ?? "" },
      body: JSON.stringify(wire),
    });
    expect(response.status).toBe(400);
    const body = (await response.json()) as { details: Array<{ field: string }> };
    expect(body.details.map((d) => d.field)).toContain("value");
  });

  it("trackBatch with one valid and one invalid event is partial", async () => {
    const uid = userId();
    const receipt = await hub.trackBatch([
      { userId: uid, type: "conversion", name: CONVERSION_EVENT },
      { userId: uid, type: "conversion", name: CONVERSION_EVENT, timestamp: "not-a-date" },
    ]);
    expect(receipt.status).toBe("partial");
    expect(receipt.accepted).toBe(1);
    expect(receipt.rejected).toBe(1);
    expect(receipt.errors[0].index).toBe(1);
  });

  it("evaluates a seeded flag with an API key (current_scope probe)", async () => {
    const result = await hub.flags.evaluate({ key: FLAG, context: { user_id: userId() } });
    expect(result.key).toBe(FLAG);
    expect(typeof result.enabled).toBe("boolean");
  });

  it("throws NotFoundError for an unknown flag", async () => {
    await expect(hub.flags.evaluate({ key: "no-such-flag" })).rejects.toBeInstanceOf(NotFoundError);
  });

  it("rejects a wrong API key with AuthenticationError", async () => {
    const bad = createClient({ baseUrl: BASE_URL ?? "", apiKey: "eh_live_definitely_wrong" });
    await expect(bad.assign({ userId: userId(), experimentKey: RUNNING })).rejects.toBeInstanceOf(
      AuthenticationError,
    );
  });
});

describe.skipIf(enabled)("live contract (disabled)", () => {
  it.skip("set EXPERIMENT_HUB_BASE_URL and EXPERIMENT_HUB_API_KEY to run the contract suite", () => {});
});
```

- [ ] **Step 2: Verify it is skipped without env vars**

Run: `npm run test:contract`
Expected: the suite reports skipped tests, exit code 0, and the "disabled" describe shows the hint.

- [ ] **Step 3: Run it against the live stack**

Get the API key from the most recent `mix dev.demo` output (re-run `mix dev.demo` from the repo root if unsure — it reseeds and prints a fresh key). Then from `sdk/javascript/`:

PowerShell:
```powershell
$env:EXPERIMENT_HUB_BASE_URL = "http://127.0.0.1:4000"; $env:EXPERIMENT_HUB_API_KEY = "<key>"; npm run test:contract
```
Bash:
```bash
EXPERIMENT_HUB_BASE_URL=http://127.0.0.1:4000 EXPERIMENT_HUB_API_KEY=<key> npm run test:contract
```

Expected: 10 tests pass. Record exactly which tests failed, if any, with the server's response body.

- [ ] **Step 4: If — and only if — the flags probe fails with a 500**

The symptom is `ApiError` with status 500 from `flags.evaluate` while every other test passes. Cause: `feature_flag_controller.ex` reads `conn.assigns[:current_scope].tenant_id`, which `ApiKeyAuth` does not set. Fix both `evaluate/2` and `evaluate_batch/2` to read the tenant the way `assign_controller.ex` does:

```elixir
  def evaluate(conn, %{"key" => key} = params) do
    tenant_id = conn.assigns.tenant_id
    context = params["context"] || %{}
    # ...unchanged
  end

  def evaluate_batch(conn, %{"keys" => keys} = params) do
    tenant_id = conn.assigns.tenant_id
    context = params["context"] || %{}
    # ...unchanged
  end
```

First confirm `TenantContext` sets `conn.assigns.tenant_id` for both auth paths (`grep -n "assign(conn, :tenant_id" apps/experiment_hub_web/lib/experiment_hub_web/plugs/tenant_context.ex`). Restart `mix phx.server`, re-run the contract suite, then run the Elixir tests for that controller: `mix test apps/experiment_hub_web/test/experiment_hub_web/controllers/feature_flag_controller_test.exs`. Commit the server fix separately:

```bash
git add apps/experiment_hub_web/lib/experiment_hub_web/controllers/feature_flag_controller.ex
git commit -m "fix(web): flag evaluation reads tenant_id so API-key callers get 200 not 500

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

If the probe passes, skip this step and note in the task report that `current_scope` is populated for API-key auth.

- [ ] **Step 5: Commit the contract suite**

```bash
git add sdk/javascript/test/contract/live.contract.test.ts
git commit -m "test(sdk-js): opt-in live contract suite against the demo tenant

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: CI job

**Files:**

- Modify: `.github/workflows/ci.yml` (add a job after `dashboard`, around line 131)

- [ ] **Step 1: Read the existing `dashboard` job** (`.github/workflows/ci.yml:112-131`) and copy its structure exactly — same `actions/checkout` and `actions/setup-node` versions and the same cache settings.

- [ ] **Step 2: Add the `sdk-js` job** directly after the `dashboard` job:

```yaml
  sdk-js:
    name: JavaScript SDK
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: sdk/javascript
    steps:
      - uses: actions/checkout@v4            # match the version the dashboard job uses
      - uses: actions/setup-node@v4          # match the version the dashboard job uses
        with:
          node-version: "24"
          cache: npm
          cache-dependency-path: sdk/javascript/package-lock.json
      - run: npm ci
      - run: npm run check
```

If the `docker-builds` or `release-smoke-test` jobs declare `needs:` listing the other jobs, add `sdk-js` to those lists so a broken SDK blocks the release path like a broken dashboard does.

- [ ] **Step 3: Validate the YAML**

Run: `node -e "const y=require('js-yaml')" 2>/dev/null || npx --yes yaml-lint .github/workflows/ci.yml` — if neither is available, run `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` from the repo root. Expected: no parse error.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: typecheck, lint, test, and build the JavaScript SDK

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Documentation — SDK README, quickstart rewrite, API reference fixes, root README

**Files:**

- Create: `sdk/javascript/README.md`
- Modify: `docs/sdk/javascript-quickstart.md` (full rewrite), `docs/api-reference.md` (sections "Experiments" lifecycle routes, "Assignments", "Events", "Feature Flags"), `README.md` (repo layout + integration pointer)

- [ ] **Step 1: Write `sdk/javascript/README.md`**

````markdown
# @experiment-hub/sdk

TypeScript client for the ExperimentHub runtime API: variant assignment,
event tracking, and feature flags. Zero runtime dependencies; Node ≥ 18.

> The API key is a **tenant secret**. Use this SDK server-side (Node, Next.js
> route handlers / server components, edge functions). Never ship the key to a
> browser.

## Install (from this monorepo)

```bash
cd sdk/javascript && npm install && npm run build
# in your app:
npm install ../path/to/A-B-Testing-Platform/sdk/javascript
```

## Usage

```ts
import { createClient, NotFoundError, NetworkError } from "@experiment-hub/sdk";

const hub = createClient({
  baseUrl: process.env.EXPERIMENT_HUB_BASE_URL!,   // e.g. http://127.0.0.1:4000
  apiKey: process.env.EXPERIMENT_HUB_API_KEY!,     // eh_live_…
  timeoutMs: 2000,                                 // default
});

// 1. Which variant does this user get?
const a = await hub.assign({ userId: user.id, experimentKey: "checkout-copy-demo" });
if (a.enrolled && a.variantKey === "treatment") renderNewCopy(); else renderCurrentCopy();

// 2. What did they do? (experiment and variant UUIDs come from the assignment)
await hub.track({ userId: user.id, experimentId: a.experimentId, variantId: a.variantId, type: "conversion", name: "checkout_completed" });
await hub.track({ userId: user.id, experimentId: a.experimentId, variantId: a.variantId, type: "revenue", name: "order_completed", value: 1299 });

// Flags
const { enabled } = await hub.flags.evaluate({ key: "checkout_reassurance", context: { user_id: user.id } });
```

### `enrolled: false`

When an experiment is not running (draft / paused / concluded) or the user is
not targeted, the server returns the **control** variant with
`enrolled: false` and records nothing. Treat it as "show the baseline".

### Errors

Every failure is an `ExperimentHubError` subclass you can `instanceof`:
`ValidationError` (local pre-check or server 400), `AuthenticationError` (401),
`NotFoundError` (404), `RateLimitError` (429, with `retryAfterMs`),
`ServiceUnavailableError` (503), `NetworkError` (`code` is `network_error`,
`timeout`, or `aborted`), `ApiError` (anything else).

The SDK never fails open: if the platform is unreachable, `assign` throws.
Decide that policy in your app:

```ts
async function assignOrControl(userId: string, experimentKey: string) {
  try {
    return await hub.assign({ userId, experimentKey }, { signal: AbortSignal.timeout(300) });
  } catch (err) {
    if (err instanceof NetworkError || err instanceof ServiceUnavailableError) {
      return { variantKey: "control", enrolled: false } as const; // degrade silently
    }
    throw err; // misconfiguration should be loud
  }
}
```

### Batches

`assignBatch({ userId, experimentKeys })` returns per-item results; unknown
keys appear as `{ experimentKey, error }` (use `isBatchAssignmentError`).
`trackBatch(events)` accepts 1–1000 events and resolves with
`status: "accepted" | "partial"`; it throws `ValidationError` only if the
server rejected every event.

## Development

```bash
npm run check          # typecheck + lint + unit tests + build
npm run test:contract  # live suite; needs EXPERIMENT_HUB_BASE_URL and EXPERIMENT_HUB_API_KEY
```

The contract suite runs against the `mix dev.demo` tenant and is the guard
against the SDK and server drifting apart. Start the stack with the
`run-stack` skill (or `docker compose up -d`, `mix ecto.migrate`,
`mix dev.demo`, `mix phx.server`), then export the key `mix dev.demo` prints.
````

- [ ] **Step 2: Rewrite `docs/sdk/javascript-quickstart.md`** so that every snippet compiles against the real package. Keep the headings (Installation, Configuration, Get a Variant Assignment, Track Events, Batch Events, Feature Flags) and replace the contents: install from the monorepo path (no npm publish yet); `createClient` with `baseUrl`/`apiKey` (no `tenantId` — the key identifies the tenant); `assign` takes `attributes` not `context` and returns `variantKey`/`enrolled`; `track` takes `{ userId, experimentId, variantId, type, name, value? }` using the UUIDs from the assignment; remove the React Hook section and replace with one sentence: "A React package is not shipped; with server-side assignment the variant is a prop." Link to `sdk/javascript/README.md` for errors and fail-open.

- [ ] **Step 3: Fix `docs/api-reference.md`** — the runtime sections must match `apps/experiment_hub_web/lib/experiment_hub_web/router.ex:104-112` and `:115-124`:

  - "Experiments": `POST /experiments/:id/launch` → `POST /api/v1/experiments/:id/start`; add the `/api/v1` prefix to every management route in the section if it is missing.
  - "Assignments": `POST /assignments` → `POST /v1/assign` with body `{ "user_id", "experiment_key", "attributes" }` and the real response fields (`experiment_key, variant_key, variant_name, experiment_id, variant_id, is_control, enrolled, assigned_at`); add `POST /v1/assign/batch` `{ "user_id", "experiment_keys", "attributes" }` → `{ user_id, assignments: [...], assigned_at }`.
  - "Events": `POST /v1/events` body `{ user_id, event_type, event_name, timestamp, idempotency_key, value?, properties? }` → `202 { status, event_id, received_at }`; `POST /v1/events/batch` `{ events: [...] }` → 202/207/400 `{ status: accepted|partial|rejected, accepted, rejected, errors }`. State explicitly that events require a UUID `experiment_id` and should carry `variant_id` (the rollup buckets by both).
  - "Feature Flags": `GET /flags/:flag_key` → `POST /api/v1/flags/evaluate` `{ key, context }` → `{ key, enabled }`; add `POST /api/v1/flags/evaluate/batch` `{ keys, context }` → `{ data: [...] }`.
  - Authentication: state `X-API-Key: <key>` for runtime routes and `Authorization: Bearer <jwt>` for the dashboard/management routes.

  Do not touch sections for routes this plan did not verify (GDPR, results, register).

- [ ] **Step 4: Update the root `README.md`** — add a row for `sdk/javascript/` in the repo layout table (find the table by `grep -n "dashboard/" README.md`), and under the section that explains how to use the platform add one paragraph:

  > **Integrating an application.** Your app calls `POST /v1/assign` to pick a variant and `POST /v1/events` to report outcomes; everything else (stickiness, dedup, stats) happens server-side. The TypeScript client in [`sdk/javascript/`](sdk/javascript/README.md) wraps both with typed errors and a live contract suite.

- [ ] **Step 5: Check links and commit**

Run from the repo root: `grep -n "sdk/javascript" README.md docs/sdk/javascript-quickstart.md docs/api-reference.md` — every relative link must point at an existing path (`ls` each one).

```bash
git add sdk/javascript/README.md docs/sdk/javascript-quickstart.md docs/api-reference.md README.md
git commit -m "docs: SDK README, corrected JS quickstart and API reference runtime routes

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Self-review (done while writing)

- **Spec coverage.** §4 package → Task 1. §5.1 assign → Task 4. §5.2 events (pre-validation, defaults, batch guard, partial semantics) → Task 5. §5.3 flags + `current_scope` risk → Tasks 6, 8. §5.4 errors (all eight classes, `Retry-After` ms, rate-limit headers, generic message) → Task 2. §5.5 transport (headers, UA on Node only, timeout, caller signal, no retries, pure factory) → Tasks 3, 7. §6 structure → file map. §7 unit + contract + CI → Tasks 1–8, 9. §8 docs → Task 10.
- **Type consistency.** `createTransport(config)` signature is identical in Tasks 3, 4, 5, 6 tests. `toWireEvent(input, index?)` used by Task 8 matches Task 5. `RateLimitError` extra fields match between Task 2 class and test. `BatchEventReceipt` shape in Task 1 types equals the server body asserted in Task 5.
- **Known subtlety handled in code:** `errorFromResponse` only sets `code` when the server sent one, so subclass defaults survive (Task 2 Step 3).
