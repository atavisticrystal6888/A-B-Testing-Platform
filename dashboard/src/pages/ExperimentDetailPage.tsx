import { useEffect } from "react";
import { useParams } from "react-router-dom";
import { useQueryClient } from "@tanstack/react-query";
import { useExperiment, useExperimentAction } from "../hooks/useExperiments";
import { useExperimentResults } from "../hooks/useResults";
import { useWebSocket } from "../contexts/WebSocketContext";
import ConfidenceIntervalChart from "../components/charts/ConfidenceIntervalChart";
import ConversionOverTimeChart from "../components/charts/ConversionOverTimeChart";
import type { Experiment, AnalysisResults, MetricResult } from "../lib/types";

function VariantTable({ experiment, results }: { experiment: Experiment; results?: AnalysisResults }) {
  const primaryMetric = results?.metrics.find((m) => m.role === "primary");

  return (
    <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
      <div className="px-6 py-4 border-b border-gray-100">
        <h3 className="text-sm font-semibold text-gray-900">Variant Performance</h3>
      </div>
      <table className="w-full">
        <thead>
          <tr className="bg-gray-50/50 border-b border-gray-100">
            <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Variant</th>
            <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">Traffic</th>
            <th className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase">Sample Size</th>
            <th className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase">Conv. Rate</th>
            <th className="text-right px-6 py-3 text-xs font-medium text-gray-500 uppercase">Lift</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {experiment.variants.map((variant) => {
            const stats = primaryMetric?.variants?.find((v) => v.variant_key === variant.key);
            const controlStats = primaryMetric?.variants?.find((v) =>
              experiment.variants.find((ev) => ev.key === v.variant_key && ev.is_control)
            );
            const lift = stats && controlStats && controlStats.conversion_rate
              ? ((stats.conversion_rate! - controlStats.conversion_rate!) / controlStats.conversion_rate!) * 100
              : null;

            return (
              <tr key={variant.id} className="hover:bg-gray-50/50 transition-colors">
                <td className="px-6 py-4">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium text-gray-900">{variant.name}</span>
                    {variant.is_control && (
                      <span className="text-xs bg-gray-100 text-gray-600 px-1.5 py-0.5 rounded">Control</span>
                    )}
                  </div>
                  <div className="text-xs text-gray-500">{variant.key}</div>
                </td>
                <td className="px-6 py-4 text-sm text-gray-600">
                  {(variant.traffic_allocation / 100).toFixed(1)}%
                </td>
                <td className="px-6 py-4 text-sm text-gray-600 text-right">
                  {stats?.sample_size?.toLocaleString() ?? "—"}
                </td>
                <td className="px-6 py-4 text-sm text-gray-900 text-right font-medium">
                  {stats?.conversion_rate != null ? `${(stats.conversion_rate * 100).toFixed(2)}%` : "—"}
                </td>
                <td className="px-6 py-4 text-right">
                  {lift != null ? (
                    <span className={`text-sm font-medium ${lift > 0 ? "text-green-600" : lift < 0 ? "text-red-600" : "text-gray-500"}`}>
                      {lift > 0 ? "+" : ""}{lift.toFixed(2)}%
                    </span>
                  ) : (
                    <span className="text-sm text-gray-400">—</span>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function SignificanceCard({ metric }: { metric: MetricResult }) {
  const freq = metric.frequentist;
  if (!freq) return null;

  return (
    <div className={`rounded-xl border p-6 shadow-sm ${
      freq.is_significant ? "bg-green-50 border-green-200" : "bg-white border-gray-200"
    }`}>
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-gray-900">Statistical Significance</h3>
        <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${
          freq.is_significant ? "bg-green-100 text-green-700" : "bg-gray-100 text-gray-600"
        }`}>
          {freq.is_significant ? "Significant" : "Not Significant"}
        </span>
      </div>
      <div className="grid grid-cols-3 gap-4">
        <div>
          <div className="text-xs text-gray-500">p-value</div>
          <div className="text-lg font-semibold text-gray-900">{freq.p_value.toFixed(4)}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Power</div>
          <div className="text-lg font-semibold text-gray-900">{(freq.power_achieved * 100).toFixed(1)}%</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Effect Size</div>
          <div className="text-lg font-semibold text-gray-900">{(freq.effect_size.relative * 100).toFixed(2)}%</div>
        </div>
      </div>
      {metric.recommendation && (
        <div className="mt-4 pt-4 border-t border-gray-200/50">
          <p className="text-sm text-gray-600">{metric.recommendation.message}</p>
        </div>
      )}
    </div>
  );
}

export default function ExperimentDetailPage() {
  const { id } = useParams<{ id: string }>();
  const queryClient = useQueryClient();
  const { subscribeToExperiment } = useWebSocket();
  const { data: experiment, isLoading: expLoading, error: expError } = useExperiment(id!);
  const { data: results } = useExperimentResults(id!);
  const startAction = useExperimentAction("start");
  const analyzeAction = useExperimentAction("analyze");
  const pauseAction = useExperimentAction("pause");
  const resumeAction = useExperimentAction("resume");

  useEffect(() => {
    if (!id) return;

    const unsubscribe = subscribeToExperiment(id, () => {
      queryClient.invalidateQueries({ queryKey: ["results", id] });
      queryClient.invalidateQueries({ queryKey: ["experiment", id] });
    });

    return unsubscribe;
  }, [id, queryClient, subscribeToExperiment]);

  if (expLoading) return <div className="p-8 text-gray-500">Loading...</div>;
  if (expError) return <div className="p-8 text-red-500">Unable to load experiment details.</div>;
  if (!experiment) return <div className="p-8 text-red-500">Experiment not found</div>;

  const hasAnalysisResults = (results?.metrics.length ?? 0) > 0;
  const primaryMetric = hasAnalysisResults ? results?.metrics.find((m: MetricResult) => m.role === "primary") : undefined;
  const canQueueAnalysis = experiment.status === "running" || experiment.status === "paused";
  const analysisMessage = experiment.status === "draft"
    ? "Start the experiment to automatically queue the first analysis run when the analysis stack is available."
    : "Results will appear here automatically after the queued analysis run completes.";

  return (
    <div className="p-8 max-w-6xl">
      {/* Header */}
      <div className="flex items-start justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{experiment.name}</h1>
          <p className="text-sm text-gray-500 mt-1">{experiment.key}</p>
          {experiment.hypothesis && (
            <p className="text-sm text-gray-600 mt-2 max-w-2xl">{experiment.hypothesis}</p>
          )}
        </div>
        <div className="flex gap-2">
          {experiment.status === "draft" && (
            <button
              onClick={() => startAction.mutate(id!)}
              disabled={startAction.isPending}
              className="px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 transition-colors disabled:cursor-not-allowed disabled:bg-green-500"
            >
              {startAction.isPending ? "Starting..." : "Start"}
            </button>
          )}
          {experiment.status === "running" && (
            <button
              onClick={() => pauseAction.mutate(id!)}
              disabled={pauseAction.isPending}
              className="px-4 py-2 bg-yellow-600 text-white rounded-lg text-sm font-medium hover:bg-yellow-700 transition-colors disabled:cursor-not-allowed disabled:bg-yellow-500"
            >
              {pauseAction.isPending ? "Pausing..." : "Pause"}
            </button>
          )}
          {experiment.status === "paused" && (
            <button
              onClick={() => resumeAction.mutate(id!)}
              disabled={resumeAction.isPending}
              className="px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 transition-colors disabled:cursor-not-allowed disabled:bg-green-500"
            >
              {resumeAction.isPending ? "Resuming..." : "Resume"}
            </button>
          )}
        </div>
      </div>

      {/* Stats Cards */}
      {primaryMetric && <SignificanceCard metric={primaryMetric} />}

      {/* Variant Table */}
      <div className="mt-6">
        <VariantTable experiment={experiment} results={results} />
      </div>

      {!hasAnalysisResults && (
        <div className="mt-6 rounded-xl border border-sky-200 bg-sky-50 p-6 shadow-sm">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <h3 className="text-sm font-semibold text-sky-900">Analysis Pending</h3>
              <p className="mt-2 text-sm text-sky-800">{analysisMessage}</p>
            </div>

            {canQueueAnalysis && (
              <button
                onClick={() => analyzeAction.mutate(id!)}
                disabled={analyzeAction.isPending}
                className="inline-flex items-center justify-center rounded-lg bg-sky-900 px-4 py-2 text-sm font-medium text-white transition hover:bg-sky-950 disabled:cursor-not-allowed disabled:bg-sky-700"
              >
                {analyzeAction.isPending ? "Scheduling..." : "Run Analysis"}
              </button>
            )}
          </div>

          {analyzeAction.isSuccess && (
            <p className="mt-3 text-sm text-sky-800">
              Analysis queued. This panel will update automatically when persisted results arrive.
            </p>
          )}

          {analyzeAction.isError && (
            <p className="mt-3 text-sm text-red-700">
              The analysis queue is unavailable right now. Start Oban and the statistical engine, then try again.
            </p>
          )}
        </div>
      )}

      {/* Charts */}
      {hasAnalysisResults && results && (
        <div className="grid grid-cols-2 gap-6 mt-6">
          <ConfidenceIntervalChart results={results} />
          <ConversionOverTimeChart experimentId={id!} />
        </div>
      )}

      {/* Guardrail Alerts */}
      {hasAnalysisResults && results?.guardrail_breaches && results.guardrail_breaches.length > 0 && (
        <div className="mt-6 bg-red-50 border border-red-200 rounded-xl p-6">
          <h3 className="text-sm font-semibold text-red-700 mb-2">Guardrail Breach</h3>
          {results.guardrail_breaches.map((metric: string) => (
            <p key={metric} className="text-sm text-red-600">
              Metric "{metric}" has breached its guardrail threshold.
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
