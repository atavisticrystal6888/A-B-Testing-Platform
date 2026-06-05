interface GuardrailBreachAlertProps {
  breached: boolean;
  metricName: string;
  threshold: number;
  currentValue: number;
  direction: 'above' | 'below';
}

export function GuardrailBreachAlert({
  breached,
  metricName,
  threshold,
  currentValue,
  direction,
}: GuardrailBreachAlertProps) {
  if (!breached) return null;

  return (
    <div className="rounded-lg border border-red-200 bg-red-50 p-4 flex items-start gap-3">
      <div className="flex-shrink-0 mt-0.5">
        <svg className="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
          <path
            fillRule="evenodd"
            d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
            clipRule="evenodd"
          />
        </svg>
      </div>
      <div>
        <h4 className="text-sm font-semibold text-red-800">Guardrail Breached</h4>
        <p className="text-sm text-red-700 mt-1">
          <strong>{metricName}</strong> is {currentValue.toFixed(4)}, which is{' '}
          {direction} the threshold of {threshold.toFixed(4)}.
        </p>
        <p className="text-xs text-red-600 mt-2">
          This experiment was automatically paused to prevent harm.
        </p>
      </div>
    </div>
  );
}
