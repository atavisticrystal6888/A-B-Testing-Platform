import { Experiment } from '../../lib/types';

interface ExperimentListProps {
  experiments: Experiment[];
  onSelect: (id: string) => void;
}

const statusColors: Record<string, string> = {
  draft: 'bg-gray-100 text-gray-700',
  running: 'bg-emerald-100 text-emerald-700',
  paused: 'bg-amber-100 text-amber-700',
  concluded: 'bg-blue-100 text-blue-700',
};

export function ExperimentList({ experiments, onSelect }: ExperimentListProps) {
  if (experiments.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        <p className="text-lg font-medium">No experiments found</p>
        <p className="text-sm mt-1">Create your first experiment to get started.</p>
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Name</th>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Key</th>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Status</th>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase tracking-wider">Created</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {experiments.map((exp) => (
            <tr
              key={exp.id}
              onClick={() => onSelect(exp.id)}
              className="cursor-pointer hover:bg-gray-50 transition-colors duration-150"
            >
              <td className="px-6 py-4 text-sm font-medium text-gray-900">{exp.name}</td>
              <td className="px-6 py-4 text-sm text-gray-500 font-mono">{exp.key}</td>
              <td className="px-6 py-4">
                <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${statusColors[exp.status] || 'bg-gray-100 text-gray-700'}`}>
                  {exp.status}
                </span>
              </td>
              <td className="px-6 py-4 text-sm text-gray-500">
                {new Date(exp.inserted_at).toLocaleDateString()}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
