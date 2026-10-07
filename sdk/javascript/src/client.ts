import { createAssignMethods } from "./assign";
import { ValidationError } from "./errors";
import { createEventMethods } from "./events";
import { createFlagMethods } from "./flags";
import { createTransport } from "./transport";
import type { ClientConfig, ExperimentHubClient } from "./types";

const DEFAULT_TIMEOUT_MS = 2000;

/**
 * Create an ExperimentHub client. Pure: no global state, safe to call many
 * times with different keys.
 */
export function createClient(config: ClientConfig): ExperimentHubClient {
  if (typeof config.baseUrl !== "string" || config.baseUrl.length === 0) {
    throw new ValidationError("createClient: baseUrl is required", {
      code: "config_error",
      details: [{ field: "baseUrl", error: "is required" }],
    });
  }
  if (typeof config.apiKey !== "string" || config.apiKey.length === 0) {
    throw new ValidationError("createClient: apiKey is required", {
      code: "config_error",
      details: [{ field: "apiKey", error: "is required" }],
    });
  }
  const fetchImpl = config.fetch ?? globalThis.fetch;
  if (typeof fetchImpl !== "function") {
    throw new ValidationError("createClient: no fetch available; pass config.fetch", {
      code: "config_error",
      details: [{ field: "fetch", error: "is required on runtimes without global fetch" }],
    });
  }

  const transport = createTransport({
    baseUrl: config.baseUrl,
    apiKey: config.apiKey,
    timeoutMs: config.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    fetch: config.fetch ?? fetchImpl.bind(globalThis),
    headers: config.headers ?? {},
  });

  const { assign, assignBatch } = createAssignMethods(transport);
  const { track, trackBatch } = createEventMethods(transport);
  const flags = createFlagMethods(transport);

  return { assign, assignBatch, track, trackBatch, flags };
}
