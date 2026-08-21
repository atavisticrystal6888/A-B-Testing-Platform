import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { api } from '../../lib/api';

interface PowerCalculatorStepProps {
  numVariants: number;
}

interface PowerEstimateData {
  sample_size_per_variant: number;
  total_sample_size: number;
  estimated_days: number | null;
}

interface PowerEstimateResponse {
  data: PowerEstimateData;
}

export function PowerCalculatorStep({ numVariants }: PowerCalculatorStepProps) {
  const [baselineRate, setBaselineRate] = useState('5');
  const [mde, setMde] = useState('10');
  const [power, setPower] = useState<80 | 90>(80);

  const calculatePower = useMutation({
    mutationFn: () =>
      api.post<PowerEstimateResponse>('/api/v1/power-estimate', {
        baseline_rate: Number.parseFloat(baselineRate) / 100,
        mde: Number.parseFloat(mde) / 100,
        significance_level: 0.05,
        power: power / 100,
        num_variants: numVariants,
      }),
  });

  const result = calculatePower.data?.data;

  return (
    <div className="space-y-4 p-4 bg-gray-50 rounded-xl border border-gray-200">
      <div>
        <h4 className="text-sm font-semibold text-gray-700">Power Calculator</h4>
        <p className="text-xs text-gray-400 mt-0.5">
          Optional — estimates only, doesn&apos;t affect your experiment.
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label htmlFor="power-baseline-rate" className="block text-xs font-medium text-gray-600 mb-1">
            Baseline conversion rate (%)
          </label>
          <input
            id="power-baseline-rate"
            type="number"
            min={0}
            max={100}
            step="0.1"
            value={baselineRate}
            onChange={(e) => setBaselineRate(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
        <div>
          <label htmlFor="power-mde" className="block text-xs font-medium text-gray-600 mb-1">
            Minimum detectable effect (relative %)
          </label>
          <input
            id="power-mde"
            type="number"
            min={0}
            step="0.1"
            value={mde}
            onChange={(e) => setMde(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
      </div>

      <div>
        <span className="block text-xs font-medium text-gray-600 mb-1">Desired power</span>
        <div className="flex gap-4">
          <label htmlFor="power-80" className="flex items-center gap-1.5 text-sm text-gray-700">
            <input
              id="power-80"
              type="radio"
              name="power"
              checked={power === 80}
              onChange={() => setPower(80)}
            />
            80%
          </label>
          <label htmlFor="power-90" className="flex items-center gap-1.5 text-sm text-gray-700">
            <input
              id="power-90"
              type="radio"
              name="power"
              checked={power === 90}
              onChange={() => setPower(90)}
            />
            90%
          </label>
        </div>
      </div>

      <button
        type="button"
        onClick={() => calculatePower.mutate()}
        disabled={calculatePower.isPending}
        className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
      >
        {calculatePower.isPending ? 'Calculating...' : 'Calculate'}
      </button>

      {calculatePower.isError && (
        <p className="text-xs text-red-600">
          Couldn&apos;t calculate a sample size right now. Please try again.
        </p>
      )}

      {result && (
        <div className="p-4 bg-white rounded-lg border border-indigo-100 text-sm text-gray-700">
          <p>
            You need <strong>{result.sample_size_per_variant.toLocaleString()} users per variant</strong>{' '}
            ({result.total_sample_size.toLocaleString()} total).
            {result.estimated_days !== null && (
              <>
                {' '}
                At your current traffic that&apos;s <strong>~{result.estimated_days} days</strong>.
              </>
            )}
          </p>
        </div>
      )}
    </div>
  );
}
