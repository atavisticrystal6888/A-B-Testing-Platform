import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { api, ApiError } from '../../lib/api';

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

/**
 * Validates the baseline-rate input (as a %). The engine's PowerRequest
 * enforces `baseline_rate` strictly between 0 and 1 (see
 * statistical_engine/src/models/power.py), so an empty, non-numeric, or
 * out-of-range value is rejected here before it ever reaches the engine —
 * a 422 from the engine reads as "the engine is down" if it gets that far.
 */
function validateBaselineRate(value: string): string | undefined {
  if (value.trim() === '') {
    return 'Baseline conversion rate is required.';
  }

  const parsed = Number.parseFloat(value);

  if (!Number.isFinite(parsed)) {
    return 'Enter a valid number.';
  }

  if (parsed <= 0 || parsed >= 100) {
    return 'Must be between 0% and 100%.';
  }

  return undefined;
}

/** Validates the MDE input (as a relative %); the engine requires > 0. */
function validateMde(value: string): string | undefined {
  if (value.trim() === '') {
    return 'Minimum detectable effect is required.';
  }

  const parsed = Number.parseFloat(value);

  if (!Number.isFinite(parsed)) {
    return 'Enter a valid number.';
  }

  if (parsed <= 0) {
    return 'Must be greater than 0%.';
  }

  return undefined;
}

export function PowerCalculatorStep({ numVariants }: PowerCalculatorStepProps) {
  const [baselineRate, setBaselineRate] = useState('5');
  const [mde, setMde] = useState('10');
  const [power, setPower] = useState<80 | 90>(80);

  const baselineRateError = validateBaselineRate(baselineRate);
  const mdeError = validateMde(mde);
  const isValid = !baselineRateError && !mdeError;

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
            className={`w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 ${
              baselineRateError ? 'border-red-300 bg-red-50' : 'border-gray-300'
            }`}
          />
          {baselineRateError && <p className="mt-1 text-xs text-red-600">{baselineRateError}</p>}
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
            className={`w-full px-3 py-2 border rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 ${
              mdeError ? 'border-red-300 bg-red-50' : 'border-gray-300'
            }`}
          />
          {mdeError && <p className="mt-1 text-xs text-red-600">{mdeError}</p>}
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
        onClick={() => {
          if (isValid) {
            calculatePower.mutate();
          }
        }}
        disabled={!isValid || calculatePower.isPending}
        className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
      >
        {calculatePower.isPending ? 'Calculating...' : 'Calculate'}
      </button>

      {calculatePower.isError && (
        <p className="text-xs text-red-600">
          {calculatePower.error instanceof ApiError && calculatePower.error.status === 422
            ? 'Check your inputs and try again.'
            : "Couldn't calculate a sample size right now. Please try again."}
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
