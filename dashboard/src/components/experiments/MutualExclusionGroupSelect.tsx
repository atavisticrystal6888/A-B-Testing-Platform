import { useQuery } from '@tanstack/react-query';
import { ApiError, api } from '../../lib/api';

interface ExclusionGroup {
  id: string;
  name: string;
}

interface MutualExclusionGroupSelectProps {
  selectedGroupId?: string;
  onChange: (groupId: string | undefined) => void;
}

export function MutualExclusionGroupSelect({
  selectedGroupId,
  onChange,
}: MutualExclusionGroupSelectProps) {
  const {
    data: groups = [],
    isLoading,
    error,
  } = useQuery<ExclusionGroup[]>({
    queryKey: ['experiment-groups'],
    queryFn: () =>
      api
        .get<{ data: ExclusionGroup[] }>('/api/v1/experiment-groups')
        .then((response) => response.data ?? []),
    retry: false,
  });

  const isUnsupported = error instanceof ApiError && error.status === 404;
  const helpText = isUnsupported
    ? 'Mutual exclusion groups are not exposed by this environment yet.'
    : 'Users assigned to one experiment in a group cannot be assigned to another.';

  return (
    <div>
      <label className="block text-sm font-medium text-gray-700 mb-1">
        Mutual Exclusion Group
      </label>
      <select
        value={selectedGroupId || ''}
        onChange={(e) => onChange(e.target.value || undefined)}
        disabled={isLoading || isUnsupported}
        className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
      >
        <option value="">None (no mutual exclusion)</option>
        {groups.map((g: ExclusionGroup) => (
          <option key={g.id} value={g.id}>
            {g.name}
          </option>
        ))}
      </select>
      <p className={`text-xs mt-1 ${error && !isUnsupported ? 'text-red-600' : 'text-gray-400'}`}>
        {error && !isUnsupported ? 'Unable to load mutual exclusion groups right now.' : helpText}
      </p>
    </div>
  );
}
