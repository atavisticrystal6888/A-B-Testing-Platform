import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from 'recharts';

interface FunnelStep {
  name: string;
  count: number;
  rate: number;
}

interface FunnelChartProps {
  steps: FunnelStep[];
}

const COLORS = ['#6366F1', '#818CF8', '#A5B4FC', '#C7D2FE', '#E0E7FF'];

export function FunnelChart({ steps }: FunnelChartProps) {
  const data = steps.map((step, i) => ({
    name: step.name,
    count: step.count,
    rate: step.rate * 100,
    dropoff: i > 0 ? ((steps[i - 1].count - step.count) / steps[i - 1].count) * 100 : 0,
  }));

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6">
      <h3 className="text-sm font-semibold text-gray-600 uppercase tracking-wider mb-4">
        Conversion Funnel
      </h3>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={data} layout="vertical" margin={{ left: 100 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis type="number" domain={[0, 'dataMax']} />
          <YAxis type="category" dataKey="name" width={90} tick={{ fontSize: 12 }} />
          <Tooltip
            formatter={(value: number, name: string) => {
              if (name === 'count') return [value.toLocaleString(), 'Users'];
              return [`${value.toFixed(1)}%`, 'Rate'];
            }}
          />
          <Bar dataKey="count" radius={[0, 4, 4, 0]}>
            {data.map((_, i) => (
              <Cell key={i} fill={COLORS[i % COLORS.length]} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
