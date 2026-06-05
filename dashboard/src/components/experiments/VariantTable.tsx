interface VariantResult {
  variant_id: string;
  variant_key: string;
  variant_name: string;
  is_control: boolean;
  sample_size: number;
  conversions: number;
  conversion_rate: number;
  ci_lower: number;
  ci_upper: number;
}

interface VariantTableProps {
  variants: VariantResult[];
}

export function VariantTable({ variants }: VariantTableProps) {
  return (
    <div className="overflow-hidden rounded-xl border border-gray-200 bg-white">
      <table className="min-w-full divide-y divide-gray-200">
        <thead className="bg-gray-50">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-semibold text-gray-600 uppercase">Variant</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Samples</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Conversions</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">Rate</th>
            <th className="px-6 py-3 text-right text-xs font-semibold text-gray-600 uppercase">95% CI</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-100">
          {variants.map((v) => (
            <tr key={v.variant_id} className={v.is_control ? 'bg-blue-50/30' : ''}>
              <td className="px-6 py-4 text-sm font-medium text-gray-900">
                {v.variant_name}
                {v.is_control && (
                  <span className="ml-2 text-xs text-blue-600 font-normal">(control)</span>
                )}
              </td>
              <td className="px-6 py-4 text-sm text-gray-700 text-right font-mono">
                {v.sample_size.toLocaleString()}
              </td>
              <td className="px-6 py-4 text-sm text-gray-700 text-right font-mono">
                {v.conversions.toLocaleString()}
              </td>
              <td className="px-6 py-4 text-sm text-gray-900 text-right font-mono font-medium">
                {(v.conversion_rate * 100).toFixed(2)}%
              </td>
              <td className="px-6 py-4 text-sm text-gray-500 text-right font-mono">
                [{(v.ci_lower * 100).toFixed(2)}%, {(v.ci_upper * 100).toFixed(2)}%]
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
