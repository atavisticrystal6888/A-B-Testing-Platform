import { describe, expect, it } from "vitest";
import { ApiError, NetworkError, NotFoundError, ValidationError } from "../src/errors";
import { SDK_VERSION, createTransport } from "../src/transport";
import { fakeFetch } from "./helpers/fake-fetch";

function transportWith(fetch: typeof globalThis.fetch, overrides: Partial<Parameters<typeof createTransport>[0]> = {}) {
  return createTransport({
    baseUrl: "http://hub.test",
    apiKey: "eh_live_secret",
    timeoutMs: 2000,
    fetch,
    headers: {},
    ...overrides,
  });
}

describe("transport.post", () => {
  it("POSTs JSON to baseUrl + path with auth and content headers", async () => {
    const { fetch, requests } = fakeFetch({ status: 200, body: { ok: true } });
    const result = await transportWith(fetch).post<{ ok: boolean }>("/v1/assign", { user_id: "u1" });

    expect(result).toEqual({ ok: true });
    expect(requests).toHaveLength(1);
    expect(requests[0].url).toBe("http://hub.test/v1/assign");
    expect(requests[0].method).toBe("POST");
    expect(requests[0].body).toEqual({ user_id: "u1" });
    expect(requests[0].headers["x-api-key"]).toBe("eh_live_secret");
    expect(requests[0].headers["content-type"]).toBe("application/json");
    expect(requests[0].headers["accept"]).toBe("application/json");
    expect(requests[0].headers["user-agent"]).toBe(`experiment-hub-sdk-js/${SDK_VERSION}`);
  });

  it("strips trailing slashes from baseUrl", async () => {
    const { fetch, requests } = fakeFetch();
    await transportWith(fetch, { baseUrl: "http://hub.test///" }).post("/v1/assign", {});
    expect(requests[0].url).toBe("http://hub.test/v1/assign");
  });

  it("merges extra headers, letting them override defaults except auth", async () => {
    const { fetch, requests } = fakeFetch();
    await transportWith(fetch, { headers: { "x-trace": "abc", "x-api-key": "spoof" } }).post("/p", {});
    expect(requests[0].headers["x-trace"]).toBe("abc");
    expect(requests[0].headers["x-api-key"]).toBe("eh_live_secret");
  });

  it("maps non-2xx responses through errorFromResponse", async () => {
    const { fetch } = fakeFetch(
      { status: 404, body: { error: "experiment_not_found", message: "nope" } },
      { status: 400, body: { error: "validation_error", message: "bad", details: [] } },
      { status: 500, body: "boom" },
    );
    const t = transportWith(fetch);
    await expect(t.post("/a", {})).rejects.toBeInstanceOf(NotFoundError);
    await expect(t.post("/b", {})).rejects.toBeInstanceOf(ValidationError);
    await expect(t.post("/c", {})).rejects.toBeInstanceOf(ApiError);
  });

  it("returns null for an empty 2xx body and raw text for non-JSON", async () => {
    const { fetch } = fakeFetch({ status: 202 }, { status: 200, body: "plain" });
    const t = transportWith(fetch);
    expect(await t.post("/a", {})).toBeNull();
    expect(await t.post("/b", {})).toBe("plain");
  });

  it("wraps a rejected fetch in NetworkError with cause", async () => {
    const cause = new TypeError("fetch failed");
    const fetch: typeof globalThis.fetch = async () => {
      throw cause;
    };
    const err = await transportWith(fetch).post("/a", {}).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("network_error");
    expect((err as NetworkError).cause).toBe(cause);
  });

  it("times out with NetworkError{code:'timeout'}", async () => {
    const { fetch } = fakeFetch({ delayMs: 200 });
    const err = await transportWith(fetch, { timeoutMs: 20 }).post("/slow", {}).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("timeout");
    expect((err as NetworkError).message).toContain("20 ms");
  });

  it("honours a caller-supplied AbortSignal", async () => {
    const { fetch } = fakeFetch({ delayMs: 200 });
    const controller = new AbortController();
    const pending = transportWith(fetch).post("/slow", {}, { signal: controller.signal });
    controller.abort();
    const err = await pending.catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("aborted");
  });

  it("times out reading the response body", async () => {
    const fetch: typeof globalThis.fetch = async () => {
      return new Response(
        new ReadableStream({
          start() {
            // Never close the stream - body never completes
          },
        }),
      );
    };
    const err = await transportWith(fetch, { timeoutMs: 100 }).post("/slow-body", {}).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("timeout");
    expect((err as NetworkError).message).toContain("100 ms");
  });

  it("propagates a serialisation TypeError unchanged (not NetworkError)", async () => {
    const { fetch, requests } = fakeFetch();
    const circular: Record<string, unknown> = {};
    circular.self = circular;
    const err = await transportWith(fetch).post("/a", circular).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(TypeError);
    expect(err).not.toBeInstanceOf(NetworkError);
    expect(requests).toHaveLength(0);
  });

  it("maps an already-aborted caller signal to NetworkError{code:'aborted'}", async () => {
    const { fetch } = fakeFetch({ delayMs: 200 });
    const controller = new AbortController();
    controller.abort();
    const err = await transportWith(fetch).post("/a", {}, { signal: controller.signal }).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("aborted");
  });

  it("maps a caller abort during the body read to NetworkError{code:'aborted'}", async () => {
    const { fetch } = fakeFetch({ bodyDelayMs: 500, body: { ok: true } });
    const controller = new AbortController();
    const pending = transportWith(fetch).post("/slow-body", {}, { signal: controller.signal });
    setTimeout(() => controller.abort(), 30);
    const err = await pending.catch((e: unknown) => e);
    expect(err).toBeInstanceOf(NetworkError);
    expect((err as NetworkError).code).toBe("aborted");
  });
});
