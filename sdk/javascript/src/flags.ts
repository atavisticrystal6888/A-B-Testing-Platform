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
      const raw = await transport.post<{ data: FlagEvaluation[] }>(
        "/api/v1/flags/evaluate/batch",
        { keys: input.keys, context: input.context ?? {} },
        options,
      );
      return raw.data;
    },
  };
}
