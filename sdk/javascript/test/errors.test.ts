import { describe, expect, it } from "vitest";
import {
  ApiError,
  AuthenticationError,
  ExperimentHubError,
  NetworkError,
  NotFoundError,
  RateLimitError,
  ServiceUnavailableError,
  ValidationError,
  errorFromResponse,
} from "../src/errors";

const h = (init: Record<string, string> = {}) => new Headers(init);

describe("error classes", () => {
  it("carry code, status, details and a useful name", () => {
    const err = new ValidationError("bad", { details: [{ field: "x", error: "is required" }] });
    expect(err).toBeInstanceOf(ExperimentHubError);
    expect(err).toBeInstanceOf(Error);
    expect(err.name).toBe("ValidationError");
    expect(err.code).toBe("validation_error");
    expect(err.status).toBe(400);
    expect(err.details).toEqual([{ field: "x", error: "is required" }]);
  });

  it("allow overriding the default code", () => {
    const err = new NetworkError("timed out", { code: "timeout" });
    expect(err.code).toBe("timeout");
    expect(err.status).toBeUndefined();
  });

  it("preserve cause", () => {
    const cause = new TypeError("fetch failed");
    const err = new NetworkError("boom", { cause });
    expect(err.cause).toBe(cause);
  });
});

describe("errorFromResponse", () => {
  it("maps 400 to ValidationError with the server message and details", () => {
    const err = errorFromResponse("POST", "/v1/events", 400, h(), {
      error: "validation_error",
      message: "value: is required for revenue events",
      details: [{ field: "value", error: "is required for revenue events" }],
    });
    expect(err).toBeInstanceOf(ValidationError);
    expect(err.message).toBe("value: is required for revenue events");
    expect(err.details).toEqual([{ field: "value", error: "is required for revenue events" }]);
  });

  it("maps 401 to AuthenticationError", () => {
    const err = errorFromResponse("POST", "/v1/assign", 401, h(), {
      error: "unauthorized",
      message: "Authentication required.",
    });
    expect(err).toBeInstanceOf(AuthenticationError);
    expect(err.code).toBe("unauthorized");
  });

  it("maps 404 to NotFoundError and keeps the server code", () => {
    const err = errorFromResponse("POST", "/v1/assign", 404, h(), {
      error: "experiment_not_found",
      message: "Experiment 'nope' does not exist",
    });
    expect(err).toBeInstanceOf(NotFoundError);
    expect(err.code).toBe("experiment_not_found");
    expect(err.message).toBe("Experiment 'nope' does not exist");
  });

  it("maps 429 to RateLimitError with Retry-After in ms and rate-limit headers", () => {
    const err = errorFromResponse(
      "POST",
      "/v1/assign",
      429,
      h({
        "retry-after": "7",
        "x-ratelimit-limit": "1000",
        "x-ratelimit-remaining": "0",
        "x-ratelimit-reset": "1760000000",
      }),
      { error: "rate_limited", message: "Too many requests" },
    );
    expect(err).toBeInstanceOf(RateLimitError);
    const rl = err as RateLimitError;
    expect(rl.retryAfterMs).toBe(7000);
    expect(rl.limit).toBe(1000);
    expect(rl.remaining).toBe(0);
    expect(rl.resetAt).toBe(1760000000);
  });

  it("maps 429 without headers to undefined fields", () => {
    const rl = errorFromResponse("POST", "/v1/assign", 429, h(), null) as RateLimitError;
    expect(rl.retryAfterMs).toBeUndefined();
    expect(rl.limit).toBeUndefined();
  });

  it("maps 503 to ServiceUnavailableError", () => {
    const err = errorFromResponse("POST", "/v1/events", 503, h(), {
      error: "service_unavailable",
      message: "Failed to enqueue event",
    });
    expect(err).toBeInstanceOf(ServiceUnavailableError);
  });

  it("maps any other status to ApiError with a generic message and the raw body", () => {
    const err = errorFromResponse("POST", "/v1/assign", 500, h(), "<html>oops</html>");
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(500);
    expect(err.message).toBe("POST /v1/assign failed with 500");
    expect(err.details).toBe("<html>oops</html>");
  });

  it("falls back to the generic message when the body has no message", () => {
    const err = errorFromResponse("POST", "/v1/assign", 400, h(), { error: "validation_error" });
    expect(err.message).toBe("POST /v1/assign failed with 400");
  });
});
