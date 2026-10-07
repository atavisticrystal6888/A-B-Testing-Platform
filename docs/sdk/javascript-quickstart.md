# JavaScript / TypeScript SDK Quickstart

The SDK lives in [`sdk/javascript/`](../../sdk/javascript/README.md). It is
server-side only: the API key is a tenant secret and must never reach a browser.

## Installation

The package is not published to npm yet; install it from the monorepo path.

```bash
cd sdk/javascript && npm install && npm run build
# in your app:
npm install ../path/to/A-B-Testing-Platform/sdk/javascript
```

## Configuration

```typescript
import { createClient } from "@experiment-hub/sdk";

const hub = createClient({
  baseUrl: process.env.EXPERIMENT_HUB_BASE_URL!, // e.g. http://127.0.0.1:4000
  apiKey: process.env.EXPERIMENT_HUB_API_KEY!,   // the key identifies the tenant
  timeoutMs: 2000,                               // optional, default 2000
});
```

## Usage

### Get a Variant Assignment

```typescript
const assignment = await hub.assign({
  userId: user.id,
  experimentKey: "checkout-copy-demo",
  attributes: { platform: "web", country: user.country },
});

if (assignment.enrolled && assignment.variantKey === "reassurance-copy") {
  renderReassuranceCopy();
} else {
  renderCurrentCopy();
}
```

`enrolled: false` means the experiment is not running or the user is not
targeted; the server returns the control variant and records nothing. Only
track events for assignments with `enrolled: true`: the results rollup buckets
by the event's experiment and variant ids with no assignment join, so tracking
an un-enrolled user counts them as control and biases the result.

### Track Events

Events carry the experiment and variant UUIDs from the assignment. Guard with
`assignment.enrolled`; tracking an un-enrolled user counts them as control.

```typescript
if (assignment.enrolled) {
  await hub.track({
    userId: user.id,
    experimentId: assignment.experimentId,
    variantId: assignment.variantId,
    type: "conversion",
    name: "checkout_completed",
  });

  await hub.track({
    userId: user.id,
    experimentId: assignment.experimentId,
    variantId: assignment.variantId,
    type: "revenue",
    name: "order_completed",
    value: 1299,
  });
}
```

### Batch Events

```typescript
// Take the ids from enrolled assignments (here: one experiment, two users).
const a1 = await hub.assign({ userId: "u1", experimentKey: "checkout-copy-demo" });
const a2 = await hub.assign({ userId: "u2", experimentKey: "checkout-copy-demo" });
const { experimentId } = a1;
const controlId = a1.variantId;
const treatmentId = a2.variantId;

// Only enrolled users are tracked; filter before building the batch.
const receipt = await hub.trackBatch([
  { userId: "u1", experimentId, variantId: controlId, type: "conversion", name: "checkout_completed" },
  { userId: "u2", experimentId, variantId: treatmentId, type: "revenue", name: "order_completed", value: 49.99 },
]);
// receipt.status is "accepted" or "partial"; inspect receipt.errors for rejected items
```

### Feature Flags

```typescript
const { enabled } = await hub.flags.evaluate({
  key: "checkout_reassurance",
  context: { user_id: user.id },
});

if (enabled) {
  showReassurance();
}
```

A React package is not shipped; with server-side assignment the variant is a prop.

## Error Handling and Fail-Open

Every failure is an `ExperimentHubError` subclass (`ValidationError`,
`AuthenticationError`, `NotFoundError`, `RateLimitError`,
`ServiceUnavailableError`, `NetworkError`, `ApiError`). The SDK never fails
open; see the [SDK README](../../sdk/javascript/README.md) for the error
reference and a fail-open wrapper.
