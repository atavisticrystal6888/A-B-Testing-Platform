import ConfidenceIntervalChart from "../charts/ConfidenceIntervalChart";
import ConversionOverTimeChart from "../charts/ConversionOverTimeChart";
import type { AnalysisResults } from "../../lib/types";

interface Props {
  results: AnalysisResults;
  experimentId: string;
}

/**
 * Recharts-heavy results section, loaded via React.lazy from
 * ExperimentDetailPage so the charting library ships in its own chunk
 * and only downloads once analysis results exist.
 */
export default function ExperimentResultsCharts({ results, experimentId }: Props) {
  return (
    <div className="grid grid-cols-1 gap-6 mt-6 md:grid-cols-2">
      <div className="min-w-0">
        <ConfidenceIntervalChart results={results} />
      </div>
      <div className="min-w-0">
        <ConversionOverTimeChart experimentId={experimentId} />
      </div>
    </div>
  );
}
