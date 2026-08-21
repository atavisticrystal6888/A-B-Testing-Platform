import { useState } from "react";

import { computeSrm, SRM_P_THRESHOLD } from "../../lib/srm";
import type { AnalysisResults, Experiment } from "../../lib/types";

function dismissalKey(experimentId: string, computedAt: string): string {
  return `srm-dismissed:${experimentId}:${computedAt}`;
}

function formatPct(value: number): string {
  return `${value.toFixed(1)}%`;
}

function formatP(p: number): string {
  return p < 0.0001 ? "< 0.0001" : p.toFixed(4);
}

export function SrmWarningBanner({
  experiment,
  results,
}: {
  experiment: Experiment;
  results?: AnalysisResults;
}) {
  const computedAt = results?.computed_at;
  const [dismissedKey, setDismissedKey] = useState<string | null>(null);

  const primaryMetric = results?.metrics.find((m) => m.role === "primary");
  const variantStats = primaryMetric?.variants ?? [];

  const rows = experiment.variants
    .map((variant) => {
      const stats = variantStats.find((v) => v.variant_key === variant.key);
      return stats ? { variant, sampleSize: stats.sample_size } : null;
    })
    .filter((row): row is { variant: Experiment["variants"][number]; sampleSize: number } => row !== null);

  if (!results || !computedAt || rows.length < 2) return null;

  const key = dismissalKey(experiment.id, computedAt);
  const isDismissed = dismissedKey === key || localStorage.getItem(key) === "1";
  if (isDismissed) return null;

  const observed = rows.map((row) => row.sampleSize);
  const expectedWeights = rows.map((row) => row.variant.traffic_allocation);
  const srm = computeSrm(observed, expectedWeights);

  if (!srm || srm.pValue >= SRM_P_THRESHOLD) return null;

  const totalObserved = srm.observed.reduce((sum, n) => sum + n, 0);
  const totalExpected = srm.expected.reduce((sum, n) => sum + n, 0);
  const observedPct = srm.observed.map((n) => (totalObserved > 0 ? (n / totalObserved) * 100 : 0));
  const expectedPct = srm.expected.map((n) => (totalExpected > 0 ? (n / totalExpected) * 100 : 0));

  const observedSummary = observedPct.map(formatPct).join(" / ");
  const expectedSummary = expectedPct.map(formatPct).join(" / ");

  const handleDismiss = () => {
    localStorage.setItem(key, "1");
    setDismissedKey(key);
  };

  return (
    <div className="bg-amber-50 border border-amber-300 rounded-lg p-4 mb-6 relative">
      <button
        onClick={handleDismiss}
        aria-label="Dismiss"
        className="absolute top-3 right-3 text-amber-500 hover:text-amber-700 text-xl leading-none"
      >
        &times;
      </button>
      <p className="text-sm text-amber-900 pr-6">
        <strong className="font-semibold">Sample ratio mismatch detected</strong>
        {" — observed split "}
        {observedSummary}
        {" differs from the configured "}
        {expectedSummary}
        {" (p = "}
        {formatP(srm.pValue)}
        {"). Results may not be trustworthy; check your SDK integration and targeting rules."}
      </p>
      <ul className="mt-3 space-y-1 text-xs text-amber-700 pr-6">
        {rows.map((row, i) => (
          <li key={row.variant.id}>
            {row.variant.name}: observed {formatPct(observedPct[i])} vs expected {formatPct(expectedPct[i])}
          </li>
        ))}
      </ul>
    </div>
  );
}
