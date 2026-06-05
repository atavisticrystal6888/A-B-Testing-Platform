# JavaScript / TypeScript SDK Quickstart

## Installation

```bash
npm install @experiment-hub/sdk
# or
yarn add @experiment-hub/sdk
```

## Configuration

```typescript
import { ExperimentHub } from '@experiment-hub/sdk';

const hub = new ExperimentHub({
  baseUrl: 'https://your-instance.example.com',
  apiKey: process.env.EXPERIMENT_HUB_API_KEY!,
  tenantId: process.env.EXPERIMENT_HUB_TENANT_ID!,
});
```

## Usage

### Get a Variant Assignment

```typescript
const assignment = await hub.assign('checkout-button-color', {
  userId: user.id,
  context: { platform: 'web', country: user.country },
});

switch (assignment.variantId) {
  case 'blue':
    renderBlueButton();
    break;
  case 'green':
    renderGreenButton();
    break;
  default:
    renderDefaultButton();
}
```

### Track Events

```typescript
await hub.track('purchase', {
  experimentId: 'checkout-button-color',
  userId: user.id,
  variantId: assignment.variantId,
  properties: {
    value: order.total,
    currency: 'USD',
  },
});
```

### Batch Events

```typescript
await hub.trackBatch([
  { eventType: 'page_view', userId: 'u1', experimentId: 'exp-1', variantId: 'v1' },
  { eventType: 'click', userId: 'u2', experimentId: 'exp-1', variantId: 'v2' },
]);
```

### Feature Flags

```typescript
const darkMode = await hub.flagEnabled('dark-mode', { userId: user.id });

if (darkMode) {
  applyDarkTheme();
}
```

### React Hook (Optional)

```tsx
import { useExperiment } from '@experiment-hub/react';

function CheckoutButton() {
  const { variant, isLoading } = useExperiment('checkout-button-color');

  if (isLoading) return <ButtonSkeleton />;

  return variant === 'blue' ? <BlueButton /> : <DefaultButton />;
}
```

### Check Experiment Results

```typescript
const results = await hub.getResults('checkout-button-color');

for (const variant of results.variants) {
  console.log(`${variant.variantId}: ${variant.conversionRate} (p=${variant.pValue})`);
}
```

## Error Handling

```typescript
try {
  const assignment = await hub.assign('my-experiment', { userId: 'u1' });
} catch (error) {
  if (error instanceof ExperimentHubError) {
    switch (error.code) {
      case 'UNAUTHORIZED': // Invalid API key
      case 'NOT_FOUND':    // Experiment not found
      case 'RATE_LIMITED': // Too many requests
      case 'TIMEOUT':      // Request timed out
    }
  }
  // Fallback to control
  return { variantId: 'control' };
}
```

## Configuration Options

```typescript
const hub = new ExperimentHub({
  baseUrl: 'https://your-instance.example.com',
  apiKey: 'your-api-key',
  tenantId: 'your-tenant-id',
  timeout: 500,            // ms (default: 1000)
  retryCount: 1,           // retries on failure (default: 0)
  fallbackVariant: 'control', // returned on failure
  cacheTimeout: 60_000,    // flag cache TTL in ms (default: 60000)
});
```
