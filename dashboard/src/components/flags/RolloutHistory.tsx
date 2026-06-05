interface RolloutChange {
  percentage: number;
  changed_at: string;
  changed_by: string;
}

interface RolloutHistoryProps {
  history: RolloutChange[];
}

export function RolloutHistory({ history }: RolloutHistoryProps) {
  if (history.length === 0) return null;

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4">
      <h4 className="text-sm font-semibold text-gray-700 mb-3">Rollout History</h4>
      <div className="space-y-2">
        {history.map((change, i) => (
          <div key={i} className="flex items-center justify-between py-2 border-b border-gray-50 last:border-0">
            <div className="flex items-center gap-3">
              <div className="w-16 h-2 bg-gray-100 rounded-full overflow-hidden">
                <div
                  className="h-full bg-indigo-500 rounded-full transition-all"
                  style={{ width: `${change.percentage / 100}%` }}
                />
              </div>
              <span className="text-sm font-mono text-gray-900">{(change.percentage / 100).toFixed(0)}%</span>
            </div>
            <div className="text-xs text-gray-500">
              {change.changed_by} · {new Date(change.changed_at).toLocaleString()}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
