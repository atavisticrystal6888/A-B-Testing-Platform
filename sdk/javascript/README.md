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
import { createClient } from "@experiment-hub/sdk";

const hub = createClient({
  baseUrl: process.env.EXPERIMENT_HUB_BASE_URL!,   // e.g. http://127.0.0.1:4000
  apiKey: process.env.EXPERIMENT_HUB_API_KEY!,     // eh_live_…
  timeoutMs: 2000,                                 // default
});

// 1. Which variant does this user get?
const a = await hub.assign({ userId: user.id, experimentKey: "checkout-copy-demo" });
if (a.enrolled && a.variantKey === "reassurance-copy") renderNewCopy(); else renderCurrentCopy();

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
import { NetworkError, ServiceUnavailableError } from "@experiment-hub/sdk";

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
