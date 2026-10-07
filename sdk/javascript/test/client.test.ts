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
