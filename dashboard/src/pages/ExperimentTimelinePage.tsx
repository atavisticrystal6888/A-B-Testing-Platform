import { useMemo } from "react";
import { Link, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ReferenceLine,
  ResponsiveContainer,
} from "recharts";
import { useExperiment } from "../hooks/useExperiments";
import { api } from "../lib/api";
import { TimelineChart } from "../components/charts/TimelineChart";
import { LoadingState, ErrorState, EmptyState } from "../components/ui/QueryStates";
import type { ExperimentTimeline } from "../lib/types";

function useExperimentTimeline(id: string) {
  return useQuery<{ data: ExperimentTimeline }>({
    queryKey: ["timeline", id],
    queryFn: () => api.get<{ data: ExperimentTimeline }>(`/api/v1/experiments/${id}/timeline`),
    enabled: !!id,
  });
}

const ACTION_LABELS: Record<string, string> = {
  create: "Created",
  start: "Started",
  pause: "Paused",
  resume: "Resumed",
  conclude: "Concluded",
};

export default function ExperimentTimelinePage() {
  const { id } = useParams<{ id: string }>();
  const { data: experiment, isLoading: expLoading, error: expError, refetch: refetchExperiment } = useExperiment(id!);
  const {
    data: timelineResponse,
    isLoading: timelineLoading,
    error: timelineError,
    refetch: refetchTimeline,
  } = useExperimentTimeline(id!);

  const timeline = timelineResponse?.data;

  const cumulativeExposures = useMemo(() => {
    if (!timeline) return [];

    let total = 0;
    return timeline.daily_exposures.map((point) => {
      total += point.count;
      return { date: point.date, cumulative: total };
    });
  }, [timeline]);

  if (expLoading || timelineLoading) {
    return (
      <div className="p-8">
        <LoadingState label="Loading timeline..." />
      </div>
    );
  }
  if (expError || timelineError) {
    return (
      <div className="p-8">
        <ErrorState
          error={expError ?? timelineError}
          onRetry={() => {
            refetchExperiment();
            refetchTimeline();
          }}
          message="Unable to load experiment timeline."
        />
      </div>
    );
  }
  if (!experiment || !timeline) {
    return (
      <div className="p-8">
        <ErrorState message="Experiment not found." />
      </div>
    );
  }

  return (
    <div className="p-8 max-w-6xl">
      <div className="mb-8">
        <Link
          to={`/experiments/${experiment.id}`}
          className="text-sm text-indigo-600 hover:text-indigo-700"
        >
          ← Back to experiment
        </Link>
        <h1 className="text-2xl font-bold text-gray-900 mt-2">{experiment.name}</h1>
        <p className="text-sm text-gray-500 mt-1">Timeline</p>
      </div>

      <TimelineChart
        experiments={[
          {
            id: experiment.id,
            name: experiment.name,
            status: experiment.status,
            started_at: experiment.started_at ?? experiment.inserted_at,
            ended_at: experiment.concluded_at,
            feature_tag: experiment.feature_tag ?? "",
          },
        ]}
      />

      <div className="mt-6 bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Cumulative Exposures</h3>

        {cumulativeExposures.length === 0 ? (
          <EmptyState title="No exposures recorded yet." />
        ) : (
          <ResponsiveContainer width="100%" height={280}>
            <AreaChart data={cumulativeExposures}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
              <XAxis dataKey="date" tick={{ fontSize: 11 }} stroke="#9ca3af" />
              <YAxis tick={{ fontSize: 11 }} stroke="#9ca3af" allowDecimals={false} />
              <Tooltip />
              <Area
                type="monotone"
                dataKey="cumulative"
                stroke="#6366f1"
                fill="#6366f1"
                fillOpacity={0.2}
                name="Cumulative exposures"
              />
              {timeline.lifecycle.map((event, i) => (
                <ReferenceLine
                  key={`${event.action}-${i}`}
                  x={event.at.slice(0, 10)}
                  stroke="#9ca3af"
                  strokeDasharray="3 3"
                  label={{
                    value: ACTION_LABELS[event.action] ?? event.action,
                    position: "top",
                    fontSize: 10,
                    fill: "#6b7280",
                  }}
                />
              ))}
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="mt-6 bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
        <div className="px-6 py-4 border-b border-gray-100">
          <h3 className="text-sm font-semibold text-gray-900">Lifecycle Events</h3>
        </div>

        {timeline.lifecycle.length === 0 ? (
          <EmptyState title="No lifecycle events recorded yet." className="py-12" />
        ) : (
          <ul className="divide-y divide-gray-100">
            {timeline.lifecycle.map((event, i) => (
              <li
                key={`${event.action}-${event.at}-${i}`}
                className="px-6 py-3 flex items-center justify-between"
              >
                <div>
                  <span className="text-sm font-medium text-gray-900 capitalize">
                    {ACTION_LABELS[event.action] ?? event.action}
                  </span>
                  <span className="ml-2 text-xs text-gray-500">by {event.actor_type}</span>
                  {event.reason && (
                    <p className="text-xs text-gray-500 mt-0.5">{event.reason}</p>
                  )}
                </div>
                <span className="text-xs text-gray-500">
                  {new Date(event.at).toLocaleString()}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
