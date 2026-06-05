import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import type { MetricDefinition } from "../lib/types";

export default function MetricDefinitionsPage() {
  const { data: metrics = [], isLoading, isError } = useQuery<MetricDefinition[]>({
    queryKey: ["metric-definitions"],
    queryFn: () =>
      api
        .get<{ data: MetricDefinition[] }>("/api/v1/metric-definitions")
        .then((response) => response.data ?? []),
  });

  return (
    <div className="max-w-6xl mx-auto py-8 px-4">
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Metrics</h1>
          <p className="text-sm text-gray-500 mt-1">
            Review the metric definitions available to your tenant.
          </p>
        </div>
      </div>

      {isLoading ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center text-gray-500">
          Loading metrics...
        </div>
      ) : isError ? (
        <div className="rounded-xl border border-red-200 bg-red-50 p-12 text-center text-red-600">
          Failed to load metric definitions.
        </div>
      ) : metrics.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12 text-center text-gray-500">
          No metric definitions are available yet.
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Metric
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Key
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Description
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {metrics.map((metric: MetricDefinition) => (
                <tr key={metric.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 text-sm font-medium text-gray-900">{metric.name}</td>
                  <td className="px-6 py-4 text-sm font-mono text-gray-500">{metric.key}</td>
                  <td className="px-6 py-4 text-sm text-gray-600 capitalize">{metric.metric_type}</td>
                  <td className="px-6 py-4 text-sm text-gray-500">
                    {metric.description || "No description provided."}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}