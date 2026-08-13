import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../lib/api";
import type { MetricDefinition } from "../lib/types";

export function useMetricDefinitions() {
  return useQuery<MetricDefinition[]>({
    queryKey: ["metric-definitions"],
    queryFn: () =>
      api
        .get<{ data: MetricDefinition[] }>("/api/v1/metric-definitions")
        .then((response) => response.data ?? []),
  });
}

export function useMetricDefinition(id: string | undefined) {
  return useQuery<MetricDefinition>({
    queryKey: ["metric-definition", id],
    queryFn: () => api.get<MetricDefinition>(`/api/v1/metric-definitions/${id}`),
    enabled: !!id,
  });
}

export interface MetricDefinitionInput {
  key: string;
  name: string;
  description?: string;
  metric_type: MetricDefinition["metric_type"];
  definition: Record<string, unknown>;
}

export function useCreateMetricDefinition() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: MetricDefinitionInput) =>
      api.post<MetricDefinition>("/api/v1/metric-definitions", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["metric-definitions"] });
    },
  });
}

export function useUpdateMetricDefinition() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, ...data }: Partial<MetricDefinitionInput> & { id: string }) =>
      api.put<MetricDefinition>(`/api/v1/metric-definitions/${id}`, data),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ["metric-definitions"] });
      queryClient.invalidateQueries({ queryKey: ["metric-definition", variables.id] });
    },
  });
}

export function useDeleteMetricDefinition() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => api.delete(`/api/v1/metric-definitions/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["metric-definitions"] });
    },
  });
}
