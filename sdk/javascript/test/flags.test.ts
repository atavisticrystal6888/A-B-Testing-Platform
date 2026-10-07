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
