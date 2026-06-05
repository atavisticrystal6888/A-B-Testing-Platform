import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../lib/api";
import type { Experiment, ExperimentListResponse } from "../lib/types";

type CreateExperimentResponse = Experiment & {
  warnings?: unknown[];
};

export interface CreateExperimentInput {
  name: string;
  key: string;
  hypothesis?: string;
  feature_tag?: string;
  experiment_group_id?: string;
  variants: Array<{
    key: string;
    name: string;
    is_control: boolean;
    traffic_allocation: number;
    sort_order?: number;
  }>;
  targeting_rules?: unknown;
  scheduled_start_at?: string;
  scheduled_end_at?: string;
}

type ExperimentListResponseWithLegacyTotal = Omit<ExperimentListResponse, "meta"> & {
  meta: Omit<ExperimentListResponse["meta"], "total"> & {
    total?: number;
    total_count?: number;
  };
};

export function normalizeExperimentListResponse(
  response: ExperimentListResponseWithLegacyTotal,
): ExperimentListResponse {
  const total = response.meta.total ?? response.meta.total_count ?? response.data.length;

  return {
    ...response,
    meta: {
      ...response.meta,
      total,
    },
  };
}

export function useExperiments(params?: Record<string, string>) {
  const searchParams = new URLSearchParams(params);
  const queryString = searchParams.toString();

  return useQuery<ExperimentListResponse>({
    queryKey: ["experiments", queryString],
    queryFn: async () => {
      const response = await api.get<ExperimentListResponseWithLegacyTotal>(
        `/api/v1/experiments${queryString ? `?${queryString}` : ""}`,
      );

      return normalizeExperimentListResponse(response);
    },
  });
}

export function useExperiment(id: string) {
  return useQuery<Experiment>({
    queryKey: ["experiment", id],
    queryFn: () => api.get<Experiment>(`/api/v1/experiments/${id}`),
    enabled: !!id,
  });
}

export function useCreateExperiment() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateExperimentInput) =>
      api.post<CreateExperimentResponse>("/api/v1/experiments", data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["experiments"] });
    },
  });
}

export function useUpdateExperiment() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, ...data }: Partial<Experiment> & { id: string }) =>
      api.put<Experiment>(`/api/v1/experiments/${id}`, data),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ["experiments"] });
      queryClient.invalidateQueries({
        queryKey: ["experiment", variables.id],
      });
    },
  });
}

export function useExperimentAction(action: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) =>
      api.post(`/api/v1/experiments/${id}/${action}`),
    onSuccess: (_data, id) => {
      queryClient.invalidateQueries({ queryKey: ["experiments"] });
      queryClient.invalidateQueries({ queryKey: ["experiment", id] });
      queryClient.invalidateQueries({ queryKey: ["results", id] });
    },
  });
}
