import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ErrorBar,
  ResponsiveContainer,
} from "recharts";
import type { AnalysisResults } from "../../lib/types";

interface Props {
  results: AnalysisResults;
}

export default function ConfidenceIntervalChart({ results }: Props) {
  const primaryMetric = results.metrics.find((m) => m.role === "primary");
  if (!primaryMetric?.frequentist) return null;

  const ci = primaryMetric.frequentist.confidence_interval;

  const data = [
    {
      name: "Effect",
      value: ci.point_estimate * 100,
      errorLow: (ci.point_estimate - ci.lower) * 100,
      errorHigh: (ci.upper - ci.point_estimate) * 100,
    },
  ];

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
      <h3 className="text-sm font-semibold text-gray-900 mb-4">
        Confidence Interval ({(primaryMetric.frequentist.confidence_level * 100).toFixed(0)}%)
      </h3>
      <ResponsiveContainer width="100%" height={200}>
        <BarChart data={data} layout="vertical">
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis type="number" tickFormatter={(v) => `${v.toFixed(1)}pp`} />
          <YAxis type="category" dataKey="name" hide />
          <Tooltip
            formatter={(value: number) => `${value.toFixed(3)}pp`}
          />
          <Bar dataKey="value" fill="#6366f1" barSize={30}>
            <ErrorBar
              dataKey="errorLow"
              direction="x"
              width={8}
              strokeWidth={2}
              stroke="#4338ca"
            />
          </Bar>
        </BarChart>
      </ResponsiveContainer>
      <div className="flex justify-between text-xs text-gray-500 mt-2">
        <span>{(ci.lower * 100).toFixed(2)}pp</span>
        <span className="font-medium text-gray-700">
          {(ci.point_estimate * 100).toFixed(2)}pp
        </span>
        <span>{(ci.upper * 100).toFixed(2)}pp</span>
      </div>
    </div>
  );
}
