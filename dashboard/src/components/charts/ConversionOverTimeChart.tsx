import { useQuery } from "@tanstack/react-query";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { api } from "../../lib/api";
import { LoadingState, ErrorState, EmptyState } from "../ui/QueryStates";
import type { DailyResults } from "../../lib/types";

interface Props {
  experimentId: string;
}

const COLORS = ["#6366f1", "#f59e0b", "#10b981", "#ef4444", "#8b5cf6"];

const CARD_CLASS = "bg-white rounded-xl border border-gray-200 p-6 shadow-sm";

function formatRate(rate: number | null): string {
  return rate != null ? `${(rate * 100).toFixed(2)}%` : "no data";
}

export default function ConversionOverTimeChart({ experimentId }: Props) {
  const { data, isLoading, isError, error, refetch } = useQuery<{ data: DailyResults }>({
    queryKey: ["daily-results", experimentId],
    queryFn: () =>
      api.get<{ data: DailyResults }>(`/api/v1/experiments/${experimentId}/daily-results`),
    enabled: !!experimentId,
  });

  if (isLoading) {
    return (
      <div className={CARD_CLASS}>
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Conversion Rate Over Time</h3>
        <LoadingState label="Loading conversion data..." />
      </div>
    );
  }

  if (isError) {
    return (
      <div className={CARD_CLASS}>
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Conversion Rate Over Time</h3>
        <ErrorState
          error={error}
          onRetry={() => refetch()}
          message="Unable to load conversion data."
        />
      </div>
    );
  }

  const series = data?.data.series ?? [];

  if (series.length === 0) {
    return (
      <div className={CARD_CLASS}>
        <h3 className="text-sm font-semibold text-gray-900 mb-4">Conversion Rate Over Time</h3>
        <EmptyState
          title="No daily rollups yet"
          hint="Daily conversion rollups appear once the data pipeline has processed events for this experiment."
        />
      </div>
    );
  }

  // Recharts wants one flat row per date, keyed by variant_key -> rate.
  const variantKeys = Array.from(
    new Set(series.flatMap((entry) => entry.variants.map((v) => v.variant_key))),
  );

  const chartData = series.map((entry) => {
    const row: Record<string, string | number | null> = { date: entry.date };
    for (const variant of entry.variants) {
      row[variant.variant_key] = variant.conversion_rate;
    }
    return row;
  });

  const latest = series[series.length - 1];
  const latestRatesText = latest.variants
    .map((v) => `${v.variant_key} ${formatRate(v.conversion_rate)}`)
    .join(", ");
  const chartLabel = `Conversion rate over time chart, ${series.length} days. Latest (${latest.date}): ${latestRatesText}.`;

  return (
    <figure role="img" aria-label={chartLabel} className={CARD_CLASS}>
      <h3 className="text-sm font-semibold text-gray-900 mb-4">Conversion Rate Over Time</h3>
      <ResponsiveContainer width="100%" height={250}>
        <LineChart data={chartData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
          <XAxis dataKey="date" tick={{ fontSize: 11 }} stroke="#9ca3af" />
          <YAxis
            tickFormatter={(v: number) => `${(v * 100).toFixed(1)}%`}
            tick={{ fontSize: 11 }}
            stroke="#9ca3af"
          />
          <Tooltip
            formatter={(value: number | string | Array<number | string>) =>
              typeof value === "number" ? formatRate(value) : "—"
            }
          />
          <Legend />
          {variantKeys.map((key, i) => (
            <Line
              key={key}
              type="monotone"
              dataKey={key}
              stroke={COLORS[i % COLORS.length]}
              strokeWidth={2}
              dot={false}
              name={key}
              connectNulls
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
      <figcaption className="sr-only">{chartLabel}</figcaption>
    </figure>
  );
}
