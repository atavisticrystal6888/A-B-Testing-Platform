interface PairwiseComparison {
  variant_a: string;
  variant_b: string;
  p_value: number;
  adjusted_p_value: number;
  effect_size: number;
  is_significant: boolean;
  correction_method: string;
}

interface PairwiseComparisonTableProps {
  comparisons: PairwiseComparison[];
}

export function PairwiseComparisonTable({ comparisons }: PairwiseComparisonTableProps) {
  if (comparisons.length === 0) return null;

  return (
    <div className="rounded-xl border border-gray-200 bg-white overflow-hidden">
      <div className="px-6 py-3 bg-gray-50 border-b border-gray-200">
        <h3 className="text-sm font-semibold text-gray-600 uppercase tracking-wider">
          Pairwise Comparisons
        </h3>
        <p className="text-xs text-gray-400 mt-0.5">
          Correction: {comparisons[0]?.correction_method || 'Bonferroni'}
        </p>
      </div>
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600">Comparison</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600">P-Value</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600">Adjusted P</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600">Effect Size</th>
            <th className="px-6 py-3 text-center text-xs font-semibold text-gray-600">Significant</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {comparisons.map((c, i) => (
            <tr key={i}>
              <td className="px-6 py-3 text-sm text-gray-900">
                {c.variant_a} vs {c.variant_b}
              </td>
              <td className="px-6 py-3 text-sm font-mono text-gray-700 text-right">
                {c.p_value.toFixed(6)}
              </td>
              <td className="px-6 py-3 text-sm font-mono text-gray-700 text-right">
                {c.adjusted_p_value.toFixed(6)}
              </td>
              <td className="px-6 py-3 text-sm font-mono text-gray-700 text-right">
                {c.effect_size.toFixed(4)}
              </td>
              <td className="px-6 py-3 text-center">
                <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${
                  c.is_significant ? 'bg-emerald-100 text-emerald-700' : 'bg-gray-100 text-gray-600'
                }`}>
                  {c.is_significant ? 'Yes' : 'No'}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
