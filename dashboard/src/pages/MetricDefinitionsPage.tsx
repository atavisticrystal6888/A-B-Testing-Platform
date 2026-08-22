import { useState } from "react";
import { useMetricDefinitions } from "../hooks/useMetricDefinitions";
import { MetricDefinitionPanel } from "../components/metrics/MetricDefinitionPanel";
import { LoadingState, ErrorState, EmptyState } from "../components/ui/QueryStates";
import type { MetricDefinition } from "../lib/types";

type PanelState = { mode: "create" } | { mode: "edit"; id: string } | null;

export default function MetricDefinitionsPage() {
  const { data: metrics = [], isLoading, isError, error, refetch } = useMetricDefinitions();
  const [panelState, setPanelState] = useState<PanelState>(null);

  return (
    <div className="max-w-6xl mx-auto py-8 px-4">
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Metrics</h1>
          <p className="text-sm text-gray-500 mt-1">
            Review and manage the metric definitions available to your tenant.
          </p>
        </div>
        <button
          onClick={() => setPanelState({ mode: "create" })}
          className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 shadow-sm"
        >
          Create Metric
        </button>
      </div>

      {isLoading ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12">
          <LoadingState label="Loading metrics..." className="" />
        </div>
      ) : isError ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12">
          <ErrorState error={error} onRetry={() => refetch()} message="Failed to load metric definitions." />
        </div>
      ) : metrics.length === 0 ? (
        <div className="rounded-xl border border-gray-200 bg-white p-12">
          <EmptyState
            title="No metric definitions are available yet."
            cta={
              <button
                onClick={() => setPanelState({ mode: "create" })}
                className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 shadow-sm"
              >
                Create Metric
              </button>
            }
          />
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
          <div className="overflow-x-auto">
          <table className="min-w-[640px] w-full divide-y divide-gray-200">
            <caption className="sr-only">
              Metric definitions available to this tenant, with key, type, and description.
            </caption>
            <thead className="bg-gray-50">
              <tr>
                <th scope="col" className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Metric
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Key
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Type
                </th>
                <th scope="col" className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-gray-600">
                  Description
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {metrics.map((metric: MetricDefinition) => (
                <tr
                  key={metric.id}
                  onClick={() => setPanelState({ mode: "edit", id: metric.id })}
                  onKeyDown={(event) => {
                    if (event.key === "Enter" || event.key === " ") {
                      if (event.key === " ") {
                        event.preventDefault();
                      }
                      setPanelState({ mode: "edit", id: metric.id });
                    }
                  }}
                  tabIndex={0}
                  role="button"
                  aria-label={`Edit metric ${metric.name}`}
                  className="hover:bg-gray-50 transition-colors cursor-pointer focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-inset"
                >
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
        </div>
      )}

      {panelState?.mode === "create" && (
        <MetricDefinitionPanel mode="create" onClose={() => setPanelState(null)} />
      )}
      {panelState?.mode === "edit" && (
        <MetricDefinitionPanel mode="edit" id={panelState.id} onClose={() => setPanelState(null)} />
      )}
    </div>
  );
}
