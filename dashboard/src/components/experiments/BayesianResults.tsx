interface BayesianVariantResult {
  variant_name: string;
  probability_of_being_best: number;
  expected_loss: number;
  credible_interval: [number, number];
  is_control: boolean;
}

interface BayesianResultsProps {
  variants: BayesianVariantResult[];
  methodology: string;
}

export function BayesianResults({ variants, methodology }: BayesianResultsProps) {
  const sortedVariants = [...variants].sort(
    (a, b) => b.probability_of_being_best - a.probability_of_being_best
  );

  return (
    <div className="rounded-xl border border-gray-200 bg-white overflow-hidden">
      <div className="px-6 py-4 bg-gradient-to-r from-purple-50 to-indigo-50 border-b border-gray-200">
        <h3 className="text-sm font-semibold text-gray-800">Bayesian Analysis</h3>
        <p className="text-xs text-gray-500 mt-0.5 capitalize">{methodology}</p>
      </div>

      <div className="divide-y divide-gray-100">
        {sortedVariants.map((v) => (
          <div key={v.variant_name} className="px-6 py-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-900">
                {v.variant_name}
                {v.is_control && (
                  <span className="ml-2 text-xs text-blue-600">(control)</span>
                )}
              </span>
              <span className="text-sm font-mono font-semibold text-indigo-600">
                {(v.probability_of_being_best * 100).toFixed(1)}% best
              </span>
            </div>

            {/* Probability bar */}
            <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden mb-3">
              <div
                className="h-full bg-indigo-500 rounded-full transition-all duration-500"
                style={{ width: `${v.probability_of_being_best * 100}%` }}
              />
            </div>

            <div className="flex gap-6 text-xs text-gray-500">
              <div>
                <span className="text-gray-400">Expected Loss:</span>{' '}
                <span className="font-mono">{v.expected_loss.toFixed(6)}</span>
              </div>
              <div>
                <span className="text-gray-400">95% CI:</span>{' '}
                <span className="font-mono">
                  [{(v.credible_interval[0] * 100).toFixed(2)}%,{' '}
                  {(v.credible_interval[1] * 100).toFixed(2)}%]
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
