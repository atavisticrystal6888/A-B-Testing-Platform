interface AuditLogEntry {
  id: string;
  action: string;
  resource_type: string;
  resource_id: string;
  actor_id: string;
  actor_type: string;
  changes: Record<string, unknown>;
  timestamp: string;
}

interface AuditLogEntryProps {
  entry: AuditLogEntry;
}

function getChangeValues(change: unknown): { from: unknown; to: unknown } {
  if (change && typeof change === 'object' && 'from' in change && 'to' in change) {
    const pair = change as { from: unknown; to: unknown };
    return { from: pair.from, to: pair.to };
  }

  return { from: undefined, to: change };
}

export function AuditLogEntryComponent({ entry }: AuditLogEntryProps) {
  return (
    <div className="px-6 py-4 border-b border-gray-100 hover:bg-gray-50 transition-colors">
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-3">
          <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium ${
            entry.actor_type === 'system' ? 'bg-gray-100 text-gray-600' : 'bg-indigo-100 text-indigo-600'
          }`}>
            {entry.actor_type === 'system' ? '⚙' : entry.actor_id?.slice(0, 2).toUpperCase()}
          </div>
          <div>
            <p className="text-sm font-medium text-gray-900">
              {entry.action.replace(/_/g, ' ')}
            </p>
            <p className="text-xs text-gray-500">
              {entry.resource_type} · {entry.resource_id.slice(0, 8)}...
            </p>
          </div>
        </div>
        <span className="text-xs text-gray-400">
          {new Date(entry.timestamp).toLocaleString()}
        </span>
      </div>

      {entry.changes && Object.keys(entry.changes).length > 0 && (
        <div className="mt-3 ml-11 p-3 bg-gray-50 rounded-lg">
          <p className="text-xs font-medium text-gray-500 mb-2">Changes</p>
          <div className="space-y-1">
            {Object.entries(entry.changes).map(([field, change]) => (
              (() => {
                const { from, to } = getChangeValues(change);

                return (
                  <div key={field} className="flex items-center gap-2 text-xs">
                    <span className="font-medium text-gray-600">{field}:</span>
                    <span className="text-red-500 line-through">{String(from)}</span>
                    <span className="text-gray-400">→</span>
                    <span className="text-emerald-600">{String(to)}</span>
                  </div>
                );
              })()
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
