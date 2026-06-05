import { TargetingRuleBuilder } from '../experiments/TargetingRuleBuilder';

interface FlagTargetingRulesProps {
  rules: Array<{ attribute: string; operator: string; value: string }>;
  onChange: (rules: Array<{ attribute: string; operator: string; value: string }>) => void;
}

export function FlagTargetingRules({ rules, onChange }: FlagTargetingRulesProps) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-5">
      <h3 className="text-sm font-semibold text-gray-700 mb-3">Flag Targeting Rules</h3>
      <p className="text-xs text-gray-400 mb-4">
        Restrict this flag to users matching specific attributes.
      </p>
      <TargetingRuleBuilder rules={rules} onChange={onChange} />
    </div>
  );
}
