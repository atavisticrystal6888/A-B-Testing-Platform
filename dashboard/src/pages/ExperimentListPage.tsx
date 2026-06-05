import { useState } from "react";
import { Link } from "react-router-dom";
import { useExperiments } from "../hooks/useExperiments";
import type { ExperimentStatus, ExperimentSummary } from "../lib/types";

const STATUS_COLORS: Record<ExperimentStatus, string> = {
  draft: "bg-gray-100 text-gray-700",
  running: "bg-green-100 text-green-700",
  paused: "bg-yellow-100 text-yellow-700",
  concluded: "bg-blue-100 text-blue-700",
};

function StatusBadge({ status }: { status: ExperimentStatus }) {
  return (
    <span
      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${STATUS_COLORS[status]}`}
    >
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </span>
  );
}

export default function ExperimentListPage() {
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [search, setSearch] = useState("");

  const params: Record<string, string> = {};
  if (statusFilter) params.status = statusFilter;
  if (search) params.search = search;

  const { data, isLoading, error } = useExperiments(params);

  return (
    <div className="p-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Experiments</h1>
          <p className="text-sm text-gray-500 mt-1">
            Manage your A/B tests and experiments
          </p>
        </div>
        <Link
          to="/experiments/new"
          className="inline-flex items-center px-4 py-2.5 bg-indigo-600 text-white rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors shadow-sm"
        >
          + New Experiment
        </Link>
      </div>

      {/* Filters */}
      <div className="flex gap-4 mb-6">
        <input
          type="text"
          placeholder="Search experiments..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="flex-1 max-w-sm px-4 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none"
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-4 py-2 border border-gray-300 rounded-lg text-sm bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none"
        >
          <option value="">All statuses</option>
          <option value="draft">Draft</option>
          <option value="running">Running</option>
          <option value="paused">Paused</option>
          <option value="concluded">Concluded</option>
        </select>
      </div>

      {/* List */}
      {isLoading && (
        <div className="text-center py-12 text-gray-500">Loading...</div>
      )}

      {error && (
        <div className="text-center py-12 text-red-500">
          Failed to load experiments
        </div>
      )}

      {data && data.data.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 mb-4">No experiments found</p>
          <Link
            to="/experiments/new"
            className="text-indigo-600 hover:text-indigo-700 font-medium"
          >
            Create your first experiment
          </Link>
        </div>
      )}

      {data && data.data.length > 0 && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50/50">
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Experiment
                </th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Variants
                </th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Created
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {data.data.map((exp: ExperimentSummary) => (
                <tr
                  key={exp.id}
                  className="hover:bg-gray-50/50 transition-colors"
                >
                  <td className="px-6 py-4">
                    <Link
                      to={`/experiments/${exp.id}`}
                      className="text-sm font-medium text-gray-900 hover:text-indigo-600 transition-colors"
                    >
                      {exp.name}
                    </Link>
                    <div className="text-xs text-gray-500 mt-0.5">
                      {exp.key}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <StatusBadge status={exp.status} />
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-600">
                    {exp.variant_count} variants
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-500">
                    {new Date(exp.inserted_at).toLocaleDateString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination */}
      {data?.meta && data.meta.total_pages > 1 && (
        <div className="flex justify-center gap-2 mt-6">
          <span className="text-sm text-gray-500">
            Page {data.meta.page} of {data.meta.total_pages} ({data.meta.total}{" "}
            total)
          </span>
        </div>
      )}
    </div>
  );
}
