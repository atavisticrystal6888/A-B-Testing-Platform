import { useState } from 'react';

interface CustomMetricFormProps {
  onSubmit: (metric: {
    key: string;
    name: string;
    metric_type: string;
    definition: Record<string, unknown>;
  }) => void;
  onCancel: () => void;
}

export function CustomMetricForm({ onSubmit, onCancel }: CustomMetricFormProps) {
  const [key, setKey] = useState('');
  const [name, setName] = useState('');
  const [metricType, setMetricType] = useState('conversion');
  const [numeratorEvent, setNumeratorEvent] = useState('');
  const [denominatorEvent, setDenominatorEvent] = useState('');
  const [funnelSteps, setFunnelSteps] = useState<string[]>(['']);

  const handleSubmit = () => {
    let definition: Record<string, unknown> = {};

    if (metricType === 'ratio') {
      definition = { numerator_event: numeratorEvent, denominator_event: denominatorEvent };
    } else if (metricType === 'funnel') {
      definition = { steps: funnelSteps.filter(Boolean) };
    }

    onSubmit({ key, name, metric_type: metricType, definition });
  };

  return (
    <div className="space-y-4 p-6 bg-white rounded-xl border border-gray-200">
      <h3 className="text-lg font-semibold text-gray-900">Define Custom Metric</h3>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Key</label>
          <input type="text" value={key} onChange={(e) => setKey(e.target.value)} placeholder="revenue_per_user" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Name</label>
          <input type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="Revenue Per User" className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Type</label>
        <select value={metricType} onChange={(e) => setMetricType(e.target.value)} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm">
          <option value="conversion">Conversion</option>
          <option value="continuous">Continuous</option>
          <option value="ratio">Ratio</option>
          <option value="funnel">Funnel</option>
        </select>
      </div>

      {metricType === 'ratio' && (
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Numerator Event</label>
            <input type="text" value={numeratorEvent} onChange={(e) => setNumeratorEvent(e.target.value)} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Denominator Event</label>
            <input type="text" value={denominatorEvent} onChange={(e) => setDenominatorEvent(e.target.value)} className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm" />
          </div>
        </div>
      )}

      {metricType === 'funnel' && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">Funnel Steps</label>
          {funnelSteps.map((step, i) => (
            <div key={i} className="flex items-center gap-2 mb-2">
              <span className="text-sm text-gray-500 w-6">{i + 1}.</span>
              <input type="text" value={step} onChange={(e) => { const s = [...funnelSteps]; s[i] = e.target.value; setFunnelSteps(s); }} placeholder="Event name" className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm" />
            </div>
          ))}
          <button onClick={() => setFunnelSteps([...funnelSteps, ''])} className="text-sm text-indigo-600 hover:text-indigo-700">+ Add Step</button>
        </div>
      )}

      <div className="flex justify-end gap-3 pt-3">
        <button onClick={onCancel} className="px-4 py-2 text-sm text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
        <button onClick={handleSubmit} disabled={!key || !name} className="px-4 py-2 text-sm text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50">Create Metric</button>
      </div>
    </div>
  );
}
