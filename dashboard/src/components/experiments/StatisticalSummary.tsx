interface StatisticalSummaryProps {
  pValue: number | null;
  isSignificant: boolean;
  recommendation: string;
  methodology: string;
  confidenceLevel: number;
}

export function StatisticalSummary({
  pValue,
  isSignificant,
  recommendation,
  methodology,
  confidenceLevel,
}: StatisticalSummaryProps) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 space-y-4">
      <h3 className="text-sm font-semibold text-gray-600 uppercase tracking-wider">
        Statistical Summary
      </h3>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <p className="text-xs text-gray-500">Methodology</p>
          <p className="text-sm font-medium text-gray-900 capitalize">{methodology}</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Confidence Level</p>
          <p className="text-sm font-medium text-gray-900">{(confidenceLevel * 100).toFixed(0)}%</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">P-Value</p>
          <p className="text-sm font-mono font-medium text-gray-900">
            {pValue !== null ? pValue.toFixed(6) : 'N/A'}
          </p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Significance</p>
          <span
            className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
              isSignificant
                ? 'bg-emerald-100 text-emerald-700'
                : 'bg-gray-100 text-gray-600'
            }`}
          >
            {isSignificant ? 'Significant' : 'Not Significant'}
          </span>
        </div>
      </div>

      <div className="pt-3 border-t border-gray-100">
        <p className="text-xs text-gray-500">Recommendation</p>
        <p className="text-sm text-gray-800 mt-1">{recommendation}</p>
      </div>
    </div>
  );
}
