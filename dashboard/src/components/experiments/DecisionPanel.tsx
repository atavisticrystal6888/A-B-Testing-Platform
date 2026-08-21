import { deriveDecision } from "../../lib/readout";
import type { Decision } from "../../lib/readout";
import type { AnalysisResults, Experiment } from "../../lib/types";

const BORDER_BY_STATE: Record<Decision["state"], string> = {
  ship: "border-l-green-500",
  do_not_ship: "border-l-red-500",
  keep_collecting: "border-l-amber-500",
  no_effect: "border-l-gray-400",
};

export function DecisionPanel({
  experiment,
  results,
}: {
  experiment: Experiment;
  results?: AnalysisResults;
}) {
  const decision = results ? deriveDecision(experiment, results) : null;
  if (!decision) return null;

  return (
    <div
      className={`bg-white rounded-xl border border-gray-200 border-l-4 p-6 shadow-sm mb-6 ${BORDER_BY_STATE[decision.state]}`}
    >
      <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">Recommendation</p>
      <p className="text-lg font-semibold mt-1">{decision.headline}</p>
      <p className="text-sm text-gray-600 mt-1">{decision.detail}</p>
    </div>
  );
}
