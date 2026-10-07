import { describe, expect, it } from "vitest";
import * as sdk from "../src/index";

describe("public entry point", () => {
  it("exports the factory, version, and error classes", () => {
    expect(sdk.SDK_VERSION).toBe("0.1.0");
    expect(typeof sdk.createClient).toBe("function");
    expect(typeof sdk.isBatchAssignmentError).toBe("function");
    for (const name of [
      "ExperimentHubError",
      "ValidationError",
      "AuthenticationError",
      "NotFoundError",
      "RateLimitError",
      "ServiceUnavailableError",
      "NetworkError",
      "ApiError",
    ] as const) {
      expect(typeof sdk[name]).toBe("function");
    }
  });
});
