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
  // vitest still runs this callback when skipped, and createClient rejects an empty baseUrl.
  // The `unset` fallbacks are never used for a request: the tests below only run when both env vars are set.
  const hub = createClient({ baseUrl: BASE_URL ?? "http://unset.invalid", apiKey: API_KEY ?? "unset" });

  it("assigns a running experiment and is sticky per user", async () => {
    const uid = userId();
    const first = await hub.assign({ userId: uid, experimentKey: RUNNING });
    expect(first.enrolled).toBe(true);
    expect(first.experimentKey).toBe(RUNNING);
    expect(["control", "reassurance-copy"]).toContain(first.variantKey);
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
    const uid = userId();
    const { experimentId, variantId } = await hub.assign({ userId: uid, experimentKey: RUNNING });
    const receipt = await hub.track({ userId: uid, experimentId, variantId, type: "conversion", name: CONVERSION_EVENT });
    expect(receipt.status).toBe("accepted");
    expect(receipt.eventId).toMatch(/[0-9a-f-]{36}/);
  });

  it("local validation mirrors the server: metric without value is rejected by both", async () => {
    const uid = userId();
    const { experimentId, variantId } = await hub.assign({ userId: uid, experimentKey: RUNNING });
    const input = { userId: uid, experimentId, variantId, type: "metric" as const, name: "anything" };
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
    const { experimentId, variantId } = await hub.assign({ userId: uid, experimentKey: RUNNING });
    const receipt = await hub.trackBatch([
      { userId: uid, experimentId, variantId, type: "conversion", name: CONVERSION_EVENT },
      { userId: uid, experimentId, variantId, type: "conversion", name: CONVERSION_EVENT, timestamp: "not-a-date" },
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
    const bad = createClient({ baseUrl: BASE_URL ?? "http://unset.invalid", apiKey: "eh_live_definitely_wrong" });
    await expect(bad.assign({ userId: userId(), experimentKey: RUNNING })).rejects.toBeInstanceOf(
      AuthenticationError,
    );
  });
});

describe.skipIf(enabled)("live contract (disabled)", () => {
  it.skip("set EXPERIMENT_HUB_BASE_URL and EXPERIMENT_HUB_API_KEY to run the contract suite", () => {});
});
