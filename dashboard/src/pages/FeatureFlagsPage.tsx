import { useQuery } from '@tanstack/react-query';
import { FeatureFlagList } from '../components/flags/FeatureFlagList';
import { api } from '../lib/api';

interface Flag {
  id: string;
  key: string;
  name: string;
  status: string;
  rollout_percentage: number;
  inserted_at: string;
}

export function FeatureFlagsPage() {
  const { data: flags = [], isLoading, isError } = useQuery({
    queryKey: ['feature-flags'],
    queryFn: () =>
      api
        .get<{ data: Flag[] }>('/api/v1/flags')
        .then((response) => response.data ?? []),
  });

  return (
    <div className="max-w-5xl mx-auto py-8 px-4">
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Feature Flags</h1>
        <button className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 shadow-sm">
          Create Flag
        </button>
      </div>

      {isLoading ? (
        <div className="text-center py-12 text-gray-500">Loading flags...</div>
      ) : isError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 px-6 py-8 text-center text-sm text-red-700">
          Unable to load feature flags right now.
        </div>
      ) : (
        <FeatureFlagList flags={flags} onSelect={(id) => console.log('Selected flag:', id)} />
      )}
    </div>
  );
}
