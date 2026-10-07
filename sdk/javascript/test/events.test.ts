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
    const wire = toWireEvent({ userId: "u1", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "checkout_completed" });
    expect(wire.user_id).toBe("u1");
    expect(wire.experiment_id).toBe("exp-1");
    expect(wire.variant_id).toBe("var-1");
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
      experimentId: "exp-1",
      variantId: "var-1",
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

    const asString = toWireEvent({ userId: "u1", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "x", timestamp: "2026-01-02T03:04:05Z" });
    expect(asString.timestamp).toBe("2026-01-02T03:04:05Z");
  });

  it.each([
    [{ userId: "", experimentId: "e", variantId: "v", type: "conversion", name: "x" }, "user_id"],
    [{ userId: "u", experimentId: "e", variantId: "v", type: "conversion", name: "" }, "event_name"],
    [{ userId: "u", experimentId: "e", variantId: "v", type: "click", name: "x" }, "event_type"],
    [{ userId: "u", experimentId: "e", variantId: "v", type: "metric", name: "x" }, "value"],
    [{ userId: "u", experimentId: "e", variantId: "v", type: "revenue", name: "x" }, "value"],
    [{ userId: "u", experimentId: "", variantId: "v", type: "conversion", name: "x" }, "experiment_id"],
    [{ userId: "u", experimentId: "e", variantId: "", type: "conversion", name: "x" }, "variant_id"],
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
    const receipt = await methods.track({ userId: "u1", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "checkout_completed" });
    expect(requests[0].url).toBe("http://hub.test/v1/events");
    expect(requests[0].body).toMatchObject({ user_id: "u1", experiment_id: "exp-1", variant_id: "var-1",event_type: "conversion", event_name: "checkout_completed" });
    expect(receipt).toEqual({ status: "accepted", eventId: "evt-1", receivedAt: "2026-10-07T10:00:00Z" });
  });

  it("does not call fetch when local validation fails", async () => {
    const { methods, requests } = setup();
    await expect(methods.track({ userId: "u1", experimentId: "exp-1", variantId: "var-1", type: "metric", name: "x" })).rejects.toBeInstanceOf(ValidationError);
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
      { userId: "u1", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "a" },
      { userId: "u2", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "b", timestamp: "2026-01-01T00:00:00Z" },
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
    const tooMany = Array.from({ length: 1001 }, () => ({ userId: "u", experimentId: "exp-1", variantId: "var-1", type: "conversion" as const, name: "x" }));
    await expect(methods.trackBatch(tooMany)).rejects.toBeInstanceOf(ValidationError);
    expect(requests).toHaveLength(0);
  });

  it("reports the failing index in local validation errors", async () => {
    const { methods } = setup();
    const err = await methods
      .trackBatch([
        { userId: "u", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "ok" },
        { userId: "u", experimentId: "exp-1", variantId: "var-1", type: "metric", name: "no-value" },
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
    await expect(methods.trackBatch([{ userId: "u", experimentId: "exp-1", variantId: "var-1", type: "conversion", name: "x" }])).rejects.toBeInstanceOf(ValidationError);
  });
});
