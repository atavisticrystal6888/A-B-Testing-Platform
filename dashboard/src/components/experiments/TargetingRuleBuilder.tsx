interface TargetingRule {
  id?: string;
  attribute: string;
  operator: string;
  value: string;
}

interface TargetingRuleBuilderProps {
  rules: TargetingRule[];
  onChange: (rules: TargetingRule[]) => void;
}

const operators = [
  { value: 'eq', label: 'Equals' },
  { value: 'neq', label: 'Not Equals' },
  { value: 'gt', label: 'Greater Than' },
  { value: 'gte', label: 'Greater or Equal' },
  { value: 'lt', label: 'Less Than' },
  { value: 'lte', label: 'Less or Equal' },
  { value: 'in', label: 'In List' },
  { value: 'not_in', label: 'Not In List' },
  { value: 'contains', label: 'Contains' },
  { value: 'matches', label: 'Matches (Regex)' },
];

export function TargetingRuleBuilder({ rules, onChange }: TargetingRuleBuilderProps) {
  const addRule = () => {
    onChange([...rules, { attribute: '', operator: 'eq', value: '' }]);
  };

  const removeRule = (index: number) => {
    onChange(rules.filter((_, i) => i !== index));
  };

  const updateRule = (index: number, field: keyof TargetingRule, value: string) => {
    const updated = rules.map((rule, i) =>
      i === index ? { ...rule, [field]: value } : rule
    );
    onChange(updated);
  };

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <h4 className="text-sm font-medium text-gray-700">Targeting Rules</h4>
        <button
          onClick={addRule}
          className="text-sm text-indigo-600 hover:text-indigo-700 font-medium transition-colors"
        >
          + Add Rule
        </button>
      </div>

      {rules.length === 0 && (
        <p className="text-sm text-gray-400 italic">No targeting rules. All users eligible.</p>
      )}

      {rules.map((rule, index) => (
        <div key={index} className="flex items-center gap-2 p-3 bg-gray-50 rounded-lg">
          <input
            type="text"
            value={rule.attribute}
            onChange={(e) => updateRule(index, 'attribute', e.target.value)}
            placeholder="Attribute (e.g. country)"
            className="flex-1 px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-indigo-500"
          />
          <select
            value={rule.operator}
            onChange={(e) => updateRule(index, 'operator', e.target.value)}
            className="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-indigo-500"
          >
            {operators.map((op) => (
              <option key={op.value} value={op.value}>{op.label}</option>
            ))}
          </select>
          <input
            type="text"
            value={rule.value}
            onChange={(e) => updateRule(index, 'value', e.target.value)}
            placeholder="Value"
            className="flex-1 px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-indigo-500"
          />
          <button
            onClick={() => removeRule(index)}
            className="p-1.5 text-red-500 hover:text-red-700 hover:bg-red-50 rounded transition-colors"
          >
            ✕
          </button>
        </div>
      ))}
    </div>
  );
}
