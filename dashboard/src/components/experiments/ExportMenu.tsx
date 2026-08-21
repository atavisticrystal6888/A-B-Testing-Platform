import { useState } from "react";
import { downloadFile } from "../../lib/api";
import { downloadReadout } from "../../lib/readout";
import type { AnalysisResults, Experiment } from "../../lib/types";

interface ExportMenuProps {
  experiment: Experiment;
  results?: AnalysisResults;
}

/**
 * Readout (client-generated HTML summary) and raw data exports (CSV/JSON
 * via the authenticated export API — the backend supports exactly these
 * two formats).
 */
export function ExportMenu({ experiment, results }: ExportMenuProps) {
  const [error, setError] = useState<string | null>(null);

  const exportResults = (format: "csv" | "json") => {
    setError(null);
    downloadFile(
      `/api/v1/experiments/${experiment.id}/export/results?format=${format}`,
      `${experiment.key}-results.${format}`,
    ).catch(() => setError("Export failed. Is the experiment collecting data?"));
  };

  return (
    <div className="flex items-center gap-2">
      <button
        onClick={() => downloadReadout(experiment, results)}
        className="px-3 py-1.5 text-xs font-medium text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors"
        title="Self-contained HTML summary you can share or print to PDF"
      >
        Download Readout
      </button>
      <button
        onClick={() => exportResults("csv")}
        className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
      >
        Export CSV
      </button>
      <button
        onClick={() => exportResults("json")}
        className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
      >
        Export JSON
      </button>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
}
