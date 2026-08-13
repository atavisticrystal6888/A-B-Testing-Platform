import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../../lib/api';

interface FlagDetail {
  id: string;
  key: string;
  name: string;
  description: string | null;
  status: string;
  rollout_percentage: number;
  targeting_rules: Record<string, unknown> | unknown[] | null;
  inserted_at: string;
  updated_at: string;
}

interface FeatureFlagDetailPanelProps {
  flagId: string;
  onClose: () => void;
}

function hasTargetingRules(rules: FlagDetail['targeting_rules']): boolean {
  if (!rules) return false;
  if (Array.isArray(rules)) return rules.length > 0;
  return Object.keys(rules).length > 0;
}

export function FeatureFlagDetailPanel({ flagId, onClose }: FeatureFlagDetailPanelProps) {
  const queryClient = useQueryClient();

  const { data: flag, isLoading, isError } = useQuery({
    queryKey: ['feature-flag', flagId],
    queryFn: () =>
      api
        .get<{ data: FlagDetail }>(`/api/v1/flags/${flagId}`)
        .then((response) => response.data),
  });

  const toggleMutation = useMutation({
    mutationFn: (nextStatus: 'enabled' | 'disabled') =>
      api.put<{ data: FlagDetail }>(`/api/v1/flags/${flagId}`, {
        flag: { status: nextStatus },
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['feature-flags'] });
      queryClient.invalidateQueries({ queryKey: ['feature-flag', flagId] });
    },
  });

  const isEnabled = flag?.status === 'enabled' || flag?.status === 'active';

  return (
    <div
      className="fixed inset-0 z-50 flex justify-end bg-black/50 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-label="Feature flag details"
        className="h-full w-full max-w-md overflow-y-auto bg-white shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <div className="flex items-start justify-between px-6 py-5 border-b border-gray-100">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">
              {flag?.name ?? 'Feature Flag'}
            </h2>
            {flag && <p className="text-sm text-gray-500 font-mono mt-1">{flag.key}</p>}
          </div>
          <button
            onClick={onClose}
            aria-label="Close"
            className="text-gray-400 hover:text-gray-600 text-xl leading-none"
          >
            &times;
          </button>
        </div>

        {isLoading ? (
          <div className="px-6 py-12 text-center text-sm text-gray-500">
            Loading flag details...
          </div>
        ) : isError || !flag ? (
          <div className="px-6 py-12 text-center text-sm text-red-600">
            Unable to load this flag right now.
          </div>
        ) : (
          <div className="px-6 py-5 space-y-5">
            <div className="flex items-center justify-between">
              <span
                className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                  isEnabled
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-gray-100 text-gray-600'
                }`}
              >
                {flag.status}
              </span>
              <button
                onClick={() => toggleMutation.mutate(isEnabled ? 'disabled' : 'enabled')}
                disabled={toggleMutation.isPending}
                className={`px-4 py-2 text-sm font-medium rounded-lg shadow-sm transition-colors disabled:cursor-not-allowed ${
                  isEnabled
                    ? 'bg-gray-100 text-gray-700 hover:bg-gray-200 disabled:bg-gray-50'
                    : 'bg-indigo-600 text-white hover:bg-indigo-700 disabled:bg-indigo-400'
                }`}
              >
                {toggleMutation.isPending
                  ? 'Saving...'
                  : isEnabled
                    ? 'Disable'
                    : 'Enable'}
              </button>
            </div>

            {toggleMutation.isError && (
              <p className="text-sm text-red-600">
                Unable to update this flag right now.
              </p>
            )}

            {flag.description && (
              <div>
                <h3 className="text-xs font-semibold text-gray-500 uppercase mb-1">
                  Description
                </h3>
                <p className="text-sm text-gray-700">{flag.description}</p>
              </div>
            )}

            <div>
              <h3 className="text-xs font-semibold text-gray-500 uppercase mb-1">Rollout</h3>
              <p className="text-sm text-gray-700 font-mono">
                {(flag.rollout_percentage / 100).toFixed(0)}%
              </p>
            </div>

            {hasTargetingRules(flag.targeting_rules) && (
              <div>
                <h3 className="text-xs font-semibold text-gray-500 uppercase mb-1">
                  Targeting Rules
                </h3>
                <pre className="text-xs text-gray-700 bg-gray-50 border border-gray-200 rounded-lg p-3 overflow-x-auto">
                  {JSON.stringify(flag.targeting_rules, null, 2)}
                </pre>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4 pt-4 border-t border-gray-100">
              <div>
                <h3 className="text-xs font-semibold text-gray-500 uppercase mb-1">Created</h3>
                <p className="text-sm text-gray-700">
                  {new Date(flag.inserted_at).toLocaleString()}
                </p>
              </div>
              <div>
                <h3 className="text-xs font-semibold text-gray-500 uppercase mb-1">Updated</h3>
                <p className="text-sm text-gray-700">
                  {new Date(flag.updated_at).toLocaleString()}
                </p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
