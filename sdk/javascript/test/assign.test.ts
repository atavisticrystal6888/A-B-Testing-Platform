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
