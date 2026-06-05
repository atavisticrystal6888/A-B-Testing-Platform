import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';

export interface AuditLog {
  id: string;
  actor_id: string;
  actor_type: string;
  action: string;
  resource_type: string;
  resource_id: string;
  changes: Record<string, unknown>;
  reason?: string;
  timestamp: string;
}

interface AuditLogListResponse {
  data: AuditLog[];
}

interface AuditLogFilters {
  action?: string;
  resource_type?: string;
  actor_id?: string;
  from_date?: string;
  to_date?: string;
}

export function useAuditLogs(filters: AuditLogFilters = {}) {
  const params = new URLSearchParams();
  if (filters.action) params.set('action', filters.action);
  if (filters.resource_type) params.set('resource_type', filters.resource_type);
  if (filters.actor_id) params.set('actor_id', filters.actor_id);
  if (filters.from_date) params.set('from_date', filters.from_date);
  if (filters.to_date) params.set('to_date', filters.to_date);

  const queryString = params.toString();

  return useQuery<AuditLog[]>({
    queryKey: ['audit-logs', filters],
    queryFn: () =>
      api
        .get<AuditLogListResponse>(`/api/v1/audit-logs${queryString ? `?${queryString}` : ''}`)
        .then((r) => r.data),
  });
}

export function useExperimentAuditLogs(experimentId: string) {
  return useQuery<AuditLog[]>({
    queryKey: ['audit-logs', 'experiment', experimentId],
    queryFn: () =>
      api
        .get<AuditLogListResponse>(`/api/v1/experiments/${experimentId}/audit-logs`)
        .then((r) => r.data),
    enabled: !!experimentId,
  });
}
