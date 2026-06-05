interface ConclusionSummaryProps {
  decision: string;
  rationale: string;
  concludedBy: string;
  concludedAt: string;
  winnerVariantName?: string;
}

export function ConclusionSummary({
  decision,
  rationale,
  concludedBy,
  concludedAt,
  winnerVariantName,
}: ConclusionSummaryProps) {
  const decisionLabels: Record<string, { label: string; color: string }> = {
    ship_variant: { label: 'Ship Variant', color: 'bg-emerald-100 text-emerald-700' },
    revert: { label: 'Reverted to Control', color: 'bg-amber-100 text-amber-700' },
    inconclusive: { label: 'Inconclusive', color: 'bg-gray-100 text-gray-600' },
  };

  const info = decisionLabels[decision] || { label: decision, color: 'bg-gray-100 text-gray-600' };

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-6 space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-gray-600 uppercase tracking-wider">
          Experiment Concluded
        </h3>
        <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${info.color}`}>
          {info.label}
        </span>
      </div>

      {winnerVariantName && (
        <div>
          <p className="text-xs text-gray-500">Winner</p>
          <p className="text-sm font-medium text-gray-900">{winnerVariantName}</p>
        </div>
      )}

      <div>
        <p className="text-xs text-gray-500">Rationale</p>
        <p className="text-sm text-gray-800 mt-1">{rationale}</p>
      </div>

      <div className="flex gap-6 pt-3 border-t border-gray-100">
        <div>
          <p className="text-xs text-gray-500">Decided by</p>
          <p className="text-sm text-gray-700">{concludedBy}</p>
        </div>
        <div>
          <p className="text-xs text-gray-500">Date</p>
          <p className="text-sm text-gray-700">{new Date(concludedAt).toLocaleDateString()}</p>
        </div>
      </div>
    </div>
  );
}
