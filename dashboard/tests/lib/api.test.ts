import { beforeEach, describe, expect, test } from "vitest";

import { buildApiUrl, getApiBaseUrl, getWebSocketUrl } from "../../src/lib/api";

describe("api base url resolution", () => {
  beforeEach(() => {
    window.history.replaceState({}, "", "/app");
    localStorage.clear();
  });

  test("defaults to same-origin in the browser", () => {
    expect(getApiBaseUrl()).toBe(window.location.origin);
  });

  test("builds api urls from the current origin", () => {
    expect(buildApiUrl("/api/v1/experiments")).toBe(
      `${window.location.origin}/api/v1/experiments`,
    );
  });

  test("builds websocket urls from the current origin", () => {
    const expectedProtocol =
      window.location.protocol === "https:" ? "wss:" : "ws:";

    expect(getWebSocketUrl()).toBe(
      `${expectedProtocol}//${window.location.host}/socket`,
    );
  });
});