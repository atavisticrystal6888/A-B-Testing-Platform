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
