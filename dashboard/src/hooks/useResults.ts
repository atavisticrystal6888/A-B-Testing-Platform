import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import type { AnalysisResults } from "../lib/types";

export function useExperimentResults(experimentId: string) {
  return useQuery<AnalysisResults>({
    queryKey: ["results", experimentId],
    queryFn: () =>
      api.get<AnalysisResults>(
        `/api/v1/experiments/${experimentId}/results`,
      ),
    enabled: !!experimentId,
    refetchInterval: 30_000,
  });
}
