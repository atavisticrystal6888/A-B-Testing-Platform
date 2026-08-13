import { useState } from "react";
import { useMetricDefinitions } from "../../hooks/useMetricDefinitions";
import { useAttachMetric } from "../../hooks/useExperimentMetrics";
import { describeApiError } from "../../lib/api";
import type { ExperimentMetricSummary } from "../../lib/types";

interface AttachMetricModalProps {
  experimentId: string;
  attachedMetrics: ExperimentMetricSummary[];
  onClose: () => void;
}

export function AttachMetricModal({ experimentId, attachedMetrics, onClose }: AttachMetricModalProps) {
  const { data: allMetrics = [], isLoading } = useMetricDefinitions();
  const attachMutation = useAttachMetric();

  const [metricDefinitionId, setMetricDefinitionId] = useState("");
  const [role, setRole] = useState<"primary" | "secondary" | "guardrail">("secondary");
  const [threshold, setThreshold] = useState("");
  const [direction, setDirection] = useState<"above" | "below">("above");

  const attachedIds = new Set(attachedMetrics.map((metric) => metric.id));
  const availableMetrics = allMetrics.filter((metric) => !attachedIds.has(metric.id));
  const hasPrimary = attachedMetrics.some((metric) => metric.role === "primary");

  const canSubmit =
    metricDefinitionId.length > 0 &&
    (role !== "guardrail" || threshold.trim().length > 0) &&
    !attachMutation.isPending;

  const handleSubmit = () => {
    attachMutation.mutate(
      {
        experimentId,
        metric_definition_id: metricDefinitionId,
        role,
        guardrail_threshold: role === "guardrail" ? Number(threshold) : undefined,
        guardrail_direction: role === "guardrail" ? direction : undefined,
      },
      { onSuccess: onClose },
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden">
        <div className="px-6 py-5 border-b border-gray-100">
          <h2 className="text-lg font-semibold text-gray-900">Attach Metric</h2>
          <p className="text-sm text-gray-500 mt-1">
            Attach an existing metric definition to this experiment.
          </p>
        </div>

        <div className="px-6 py-5 space-y-5">
          {isLoading ? (
            <p className="text-sm text-gray-500">Loading metrics...</p>
          ) : availableMetrics.length === 0 ? (
            <p className="text-sm text-gray-500">
              {allMetrics.length === 0
                ? "No metric definitions exist yet. Create one from the Metrics page first."
                : "All existing metrics are already attached to this experiment."}
            </p>
          ) : (
            <>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Metric</label>
                <select
                  value={metricDefinitionId}
                  onChange={(event) => setMetricDefinitionId(event.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="">Select a metric</option>
                  {availableMetrics.map((metric) => (
                    <option key={metric.id} value={metric.id}>
                      {metric.name} ({metric.key})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Role</label>
                <div className="grid grid-cols-3 gap-2">
                  {(["primary", "secondary", "guardrail"] as const).map((option) => (
                    <label
                      key={option}
                      className={`flex flex-col items-center gap-1 p-3 rounded-lg border-2 cursor-pointer text-center transition-all ${
                        role === option ? "border-indigo-500 bg-indigo-50" : "border-gray-200 hover:border-gray-300"
                      } ${option === "primary" && hasPrimary ? "opacity-50" : ""}`}
                    >
                      <input
                        type="radio"
                        name="role"
                        value={option}
                        checked={role === option}
                        onChange={() => setRole(option)}
                        className="sr-only"
                      />
                      <span className="text-sm font-medium capitalize text-gray-900">{option}</span>
                    </label>
                  ))}
                </div>
                {role === "primary" && hasPrimary && (
                  <p className="mt-1 text-xs text-amber-600">
                    This experiment already has a primary metric — attaching another will fail. Remove the
                    existing primary metric first.
                  </p>
                )}
              </div>

              {role === "guardrail" && (
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Threshold</label>
                    <input
                      type="number"
                      step="0.01"
                      value={threshold}
                      onChange={(event) => setThreshold(event.target.value)}
                      placeholder="0.05"
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Direction</label>
                    <select
                      value={direction}
                      onChange={(event) => setDirection(event.target.value as "above" | "below")}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    >
                      <option value="above">Above</option>
                      <option value="below">Below</option>
                    </select>
                  </div>
                </div>
              )}
            </>
          )}

          {attachMutation.isError && (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {describeApiError(attachMutation.error, "Unable to attach this metric right now.")}
            </p>
          )}
        </div>

        <div className="px-6 py-4 bg-gray-50 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={!canSubmit}
            className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {attachMutation.isPending ? "Attaching..." : "Attach"}
          </button>
        </div>
      </div>
    </div>
  );
}
