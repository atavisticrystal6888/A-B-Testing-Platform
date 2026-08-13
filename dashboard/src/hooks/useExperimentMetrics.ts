import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../lib/api";

export interface AttachMetricInput {
  experimentId: string;
  metric_definition_id: string;
  role: "primary" | "secondary" | "guardrail";
  guardrail_threshold?: number;
  guardrail_direction?: "above" | "below";
}

export function useAttachMetric() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ experimentId, ...data }: AttachMetricInput) =>
      api.post(`/api/v1/experiments/${experimentId}/metrics`, data),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ["experiment", variables.experimentId] });
    },
  });
}

export interface DetachMetricInput {
  experimentId: string;
  experimentMetricId: string;
}

export function useDetachMetric() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ experimentId, experimentMetricId }: DetachMetricInput) =>
      api.delete(`/api/v1/experiments/${experimentId}/metrics/${experimentMetricId}`),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ["experiment", variables.experimentId] });
    },
  });
}
