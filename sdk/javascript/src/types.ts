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
  /** UUID from `Assignment.experimentId`. The server rejects events without it. */
  experimentId: string;
  /** UUID from `Assignment.variantId`. The rollup pipeline buckets by it. */
  variantId: string;
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
