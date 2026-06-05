interface RolloutSliderProps {
  value: number;
  onChange: (value: number) => void;
  disabled?: boolean;
}

export function RolloutSlider({ value, onChange, disabled }: RolloutSliderProps) {
  const percentage = (value / 100).toFixed(0);

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="text-sm font-medium text-gray-700">Rollout Percentage</label>
        <span className="text-sm font-mono font-semibold text-indigo-600">{percentage}%</span>
      </div>
      <input
        type="range"
        min={0}
        max={10000}
        step={100}
        value={value}
        onChange={(e) => onChange(parseInt(e.target.value, 10))}
        disabled={disabled}
        className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer accent-indigo-600 disabled:opacity-50"
      />
      <div className="flex justify-between text-xs text-gray-400">
        <span>0%</span>
        <span>25%</span>
        <span>50%</span>
        <span>75%</span>
        <span>100%</span>
      </div>
    </div>
  );
}
