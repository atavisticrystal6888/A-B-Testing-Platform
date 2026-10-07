import { ApiError } from "./errors";
import type { Transport } from "./transport";
import type { FlagEvaluateBatchInput, FlagEvaluateInput, FlagEvaluation, RequestOptions } from "./types";

export function createFlagMethods(transport: Transport) {
  return {
    async evaluate(input: FlagEvaluateInput, options?: RequestOptions): Promise<FlagEvaluation> {
      return transport.post<FlagEvaluation>(
        "/api/v1/flags/evaluate",
        { key: input.key, context: input.context ?? {} },
        options,
      );
    },

    async evaluateBatch(input: FlagEvaluateBatchInput, options?: RequestOptions): Promise<FlagEvaluation[]> {
      const raw = await transport.post<{ data: Record<string, boolean> } | null>(
        "/api/v1/flags/evaluate/batch",
        { keys: input.keys, context: input.context ?? {} },
        options,
      );
      // The server answers with a map of flag key to boolean; keys it does not know are absent.
      const data: unknown = raw?.data;
      if (typeof data !== "object" || data === null || Array.isArray(data)) {
        throw new ApiError("POST /api/v1/flags/evaluate/batch returned an unexpected response", {
          code: "unexpected_response",
          details: raw,
        });
      }
      return Object.entries(data).map(([key, enabled]) => ({ key, enabled: Boolean(enabled) }));
    },
  };
}
