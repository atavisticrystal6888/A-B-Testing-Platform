interface GuardrailConfigProps {
  metrics: Array<{ id: string; name: string }>;
  guardrails: Array<{
    metric_id: string;
    threshold: number;
    direction: 'above' | 'below';
  }>;
  onChange: (guardrails: Array<{ metric_id: string; threshold: number; direction: 'above' | 'below' }>) => void;
}

export function GuardrailConfig({ metrics, guardrails, onChange }: GuardrailConfigProps) {
  const addGuardrail = () => {
    onChange([...guardrails, { metric_id: '', threshold: 0, direction: 'above' }]);
  };

  const removeGuardrail = (index: number) => {
    onChange(guardrails.filter((_, i) => i !== index));
  };

  const updateGuardrail = (index: number, field: string, value: string | number) => {
    const updated = guardrails.map((g, i) =>
      i === index ? { ...g, [field]: value } : g
    );
    onChange(updated);
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h4 className="text-sm font-medium text-gray-700">Guardrail Metrics</h4>
        <button onClick={addGuardrail} className="text-sm text-indigo-600 hover:text-indigo-700 font-medium">
          + Add Guardrail
        </button>
      </div>

      {guardrails.length === 0 && (
        <p className="text-sm text-gray-400 italic">No guardrails configured.</p>
      )}

      {guardrails.map((g, index) => (
        <div key={index} className="flex items-center gap-2 p-3 bg-gray-50 rounded-lg">
          <select
            value={g.metric_id}
            onChange={(e) => updateGuardrail(index, 'metric_id', e.target.value)}
            className="flex-1 px-3 py-1.5 border border-gray-300 rounded-md text-sm"
          >
            <option value="">Select metric</option>
            {metrics.map((m) => (
              <option key={m.id} value={m.id}>{m.name}</option>
            ))}
          </select>
          <select
            value={g.direction}
            onChange={(e) => updateGuardrail(index, 'direction', e.target.value)}
            className="px-3 py-1.5 border border-gray-300 rounded-md text-sm"
          >
            <option value="above">Above</option>
            <option value="below">Below</option>
          </select>
          <input
            type="number"
            value={g.threshold}
            onChange={(e) => updateGuardrail(index, 'threshold', parseFloat(e.target.value))}
            step="0.01"
            className="w-24 px-3 py-1.5 border border-gray-300 rounded-md text-sm"
            placeholder="Threshold"
          />
          <button
            onClick={() => removeGuardrail(index)}
            className="p-1.5 text-red-500 hover:text-red-700 rounded"
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  );
}
