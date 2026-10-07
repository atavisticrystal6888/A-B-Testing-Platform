import { NetworkError, errorFromResponse } from "./errors";
import type { RequestOptions } from "./types";

export const SDK_VERSION = "0.1.0";

export interface TransportConfig {
  baseUrl: string;
  apiKey: string;
  timeoutMs: number;
  fetch: typeof globalThis.fetch;
  headers: Record<string, string>;
}

export interface Transport {
  post<T>(path: string, body: unknown, options?: RequestOptions): Promise<T>;
}

const TIMEOUT = Symbol("experiment-hub-sdk-timeout");

const isNode = typeof process !== "undefined" && Boolean(process.versions?.node);

async function parseBody(response: Response): Promise<unknown> {
  const text = await response.text();
  if (text.length === 0) return null;
  try {
    return JSON.parse(text) as unknown;
  } catch {
    return text;
  }
}

function describe(cause: unknown): string {
  return cause instanceof Error ? cause.message : String(cause);
}

export function createTransport(config: TransportConfig): Transport {
  const base = config.baseUrl.replace(/\/+$/, "");

  const baseHeaders: Record<string, string> = {
    "content-type": "application/json",
    accept: "application/json",
    ...(isNode ? { "user-agent": `experiment-hub-sdk-js/${SDK_VERSION}` } : {}),
  };
  for (const [key, value] of Object.entries(config.headers)) {
    if (key.toLowerCase() === "x-api-key") continue; // the configured key always wins
    baseHeaders[key.toLowerCase()] = value;
  }
  baseHeaders["x-api-key"] = config.apiKey;

  return {
    async post<T>(path: string, body: unknown, options: RequestOptions = {}): Promise<T> {
      // Serialise first: a bad body is a caller bug and must surface as-is, not as a NetworkError.
      const payload = JSON.stringify(body);
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(TIMEOUT), config.timeoutMs);
      const forwardAbort = () => controller.abort(options.signal?.reason);
      if (options.signal?.aborted) forwardAbort();
      options.signal?.addEventListener("abort", forwardAbort, { once: true });

      try {
        let response: Response;
        try {
          response = await config.fetch(base + path, {
            method: "POST",
            headers: baseHeaders,
            body: payload,
            signal: controller.signal,
          });
        } catch (cause) {
          if (controller.signal.aborted && controller.signal.reason === TIMEOUT) {
            throw new NetworkError(`POST ${path} timed out after ${config.timeoutMs} ms`, {
              code: "timeout",
              cause,
            });
          }
          if (controller.signal.aborted) {
            throw new NetworkError(`POST ${path} was aborted`, { code: "aborted", cause });
          }
          throw new NetworkError(`POST ${path} failed: ${describe(cause)}`, { cause });
        }

        let parsed: unknown;
        try {
          const abortPromise = new Promise<never>((_, reject) => {
            const handleAbort = () => {
              if (controller.signal.reason === TIMEOUT) {
                reject(new Error("timeout"));
              } else {
                reject(new Error("aborted"));
              }
            };
            if (controller.signal.aborted) {
              handleAbort();
            }
            controller.signal.addEventListener("abort", handleAbort, { once: true });
          });
          parsed = await Promise.race([parseBody(response), abortPromise]);
        } catch (cause) {
          if (controller.signal.aborted && controller.signal.reason === TIMEOUT) {
            throw new NetworkError(`POST ${path} timed out after ${config.timeoutMs} ms`, {
              code: "timeout",
              cause,
            });
          }
          if (controller.signal.aborted) {
            throw new NetworkError(`POST ${path} was aborted`, { code: "aborted", cause });
          }
          throw new NetworkError(`POST ${path} failed: ${describe(cause)}`, { cause });
        }

        if (!response.ok) {
          throw errorFromResponse("POST", path, response.status, response.headers, parsed);
        }
        return parsed as T;
      } finally {
        clearTimeout(timer);
        options.signal?.removeEventListener("abort", forwardAbort);
      }
    },
  };
}
