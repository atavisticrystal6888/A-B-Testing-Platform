interface FlagDetail {
  id: string;
  key: string;
  name: string;
  description?: string;
  status: string;
  rollout_percentage: number;
  targeting_rules?: unknown[];
  inserted_at: string;
  updated_at: string;
}

interface FeatureFlagDetailProps {
  flag: FlagDetail;
  onToggle: () => void;
  onEdit: () => void;
  onDelete: () => void;
}

export function FeatureFlagDetail({ flag, onToggle, onEdit, onDelete }: FeatureFlagDetailProps) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white overflow-hidden">
      <div className="px-6 py-5 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">{flag.name}</h2>
          <p className="text-sm text-gray-500 font-mono">{flag.key}</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={onToggle}
            className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors ${
              flag.status === 'active'
                ? 'bg-red-100 text-red-700 hover:bg-red-200'
                : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'
            }`}
          >
            {flag.status === 'active' ? 'Disable' : 'Enable'}
          </button>
          <button onClick={onEdit} className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
            Edit
          </button>
          <button onClick={onDelete} className="px-4 py-2 text-sm font-medium text-red-700 bg-white border border-red-300 rounded-lg hover:bg-red-50">
            Delete
          </button>
        </div>
      </div>

      <div className="px-6 py-5 grid grid-cols-2 gap-6">
        <div>
          <p className="text-xs text-gray-500">Status</p>
          <span className={`inline-flex items-center mt-1 px-2.5 py-0.5 rounded-full text-xs font-medium ${
            flag.status === 'active' ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'
          }`}>
            {flag.status}
          </span>
        </div>
        <div>
          <p className="text-xs text-gray-500">Rollout</p>
          <p className="text-sm font-medium text-gray-900 mt-1">{(flag.rollout_percentage / 100).toFixed(0)}%</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Created</p>
          <p className="text-sm text-gray-700 mt-1">{new Date(flag.inserted_at).toLocaleDateString()}</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Updated</p>
          <p className="text-sm text-gray-700 mt-1">{new Date(flag.updated_at).toLocaleDateString()}</p>
        </div>
      </div>

      {flag.description && (
        <div className="px-6 py-4 border-t border-gray-100">
          <p className="text-xs text-gray-500">Description</p>
          <p className="text-sm text-gray-800 mt-1">{flag.description}</p>
        </div>
      )}
    </div>
  );
}
