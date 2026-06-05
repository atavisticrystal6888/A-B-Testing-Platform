interface Flag {
  id: string;
  key: string;
  name: string;
  status: string;
  rollout_percentage: number;
  inserted_at: string;
}

interface FeatureFlagListProps {
  flags: Flag[];
  onSelect: (id: string) => void;
}

export function FeatureFlagList({ flags, onSelect }: FeatureFlagListProps) {
  if (flags.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        <p className="text-lg font-medium">No feature flags</p>
        <p className="text-sm mt-1">Create a flag to get started.</p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Name</th>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Key</th>
            <th className="px-6 py-3 text-center text-xs font-semibold text-gray-600 uppercase">Status</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Rollout</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {flags.map((flag) => (
            <tr key={flag.id} onClick={() => onSelect(flag.id)} className="cursor-pointer hover:bg-gray-50 transition-colors">
              <td className="px-6 py-4 text-sm font-medium text-gray-900">{flag.name}</td>
              <td className="px-6 py-4 text-sm text-gray-500 font-mono">{flag.key}</td>
              <td className="px-6 py-4 text-center">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                  flag.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'
                }`}>
                  {flag.status}
                </span>
              </td>
              <td className="px-6 py-4 text-sm text-gray-700 text-right font-mono">
                {(flag.rollout_percentage / 100).toFixed(0)}%
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
