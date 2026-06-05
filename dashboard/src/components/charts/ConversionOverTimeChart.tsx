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

interface Props {
  experimentId: string;
}

const COLORS = ["#6366f1", "#f59e0b", "#10b981", "#ef4444", "#8b5cf6"];

// Placeholder data - in production, fetched from API
const MOCK_DATA = Array.from({ length: 14 }, (_, i) => ({
  date: new Date(Date.now() - (13 - i) * 86400000).toLocaleDateString(),
  control: +(0.10 + Math.random() * 0.01 - 0.005).toFixed(4),
  treatment: +(0.12 + Math.random() * 0.01 - 0.005).toFixed(4),
}));

export default function ConversionOverTimeChart({ experimentId: _experimentId }: Props) {
  const data = MOCK_DATA;

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 shadow-sm">
      <h3 className="text-sm font-semibold text-gray-900 mb-4">
        Conversion Rate Over Time
      </h3>
      <ResponsiveContainer width="100%" height={250}>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f3f4f6" />
          <XAxis
            dataKey="date"
            tick={{ fontSize: 11 }}
            stroke="#9ca3af"
          />
          <YAxis
            tickFormatter={(v) => `${(v * 100).toFixed(1)}%`}
            tick={{ fontSize: 11 }}
            stroke="#9ca3af"
            domain={["dataMin - 0.01", "dataMax + 0.01"]}
          />
          <Tooltip
            formatter={(value: number) => `${(value * 100).toFixed(2)}%`}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="control"
            stroke={COLORS[0]}
            strokeWidth={2}
            dot={false}
            name="Control"
          />
          <Line
            type="monotone"
            dataKey="treatment"
            stroke={COLORS[1]}
            strokeWidth={2}
            dot={false}
            name="Treatment"
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
