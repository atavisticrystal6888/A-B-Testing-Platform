import { useState } from "react";
import { api, downloadFile, describeApiError } from "../../lib/api";
import { downloadReadout, buildReadoutHtml } from "../../lib/readout";
import type { AnalysisResults, Experiment } from "../../lib/types";

interface ExportMenuProps {
  experiment: Experiment;
  results?: AnalysisResults;
}

interface ShareReadoutResponse {
  data: { url: string };
}

/**
 * Readout (client-generated HTML summary) and raw data exports (CSV/JSON
 * via the authenticated export API — the backend supports exactly these
 * two formats).
 */
export function ExportMenu({ experiment, results }: ExportMenuProps) {
  const [error, setError] = useState<string | null>(null);
  const [linkCopied, setLinkCopied] = useState(false);
  const [shareUrl, setShareUrl] = useState<string | null>(null);

  const exportResults = (format: "csv" | "json") => {
    setError(null);
    downloadFile(
      `/api/v1/experiments/${experiment.id}/export/results?format=${format}`,
      `${experiment.key}-results.${format}`,
    ).catch(() => setError("Export failed. Is the experiment collecting data?"));
  };

  const copyShareLink = async () => {
    if (!results) return;

    setError(null);
    setShareUrl(null);

    let url: string;
    try {
      const html = buildReadoutHtml(experiment, results);
      const response = await api.post<ShareReadoutResponse>(
        `/api/v1/experiments/${experiment.id}/share-readout`,
        { html },
      );
      url = response.data.url;
    } catch (err) {
      setError(describeApiError(err, "Failed to create share link."));
      return;
    }

    // The share link itself was created successfully at this point — a
    // clipboard failure past here (Safari revokes the write permission once
    // this async gap has passed since the click) is not a share failure, so
    // it must never surface as "Failed to create share link." Fall back to
    // a copyable input the user can select/copy by hand instead.
    try {
      await navigator.clipboard.writeText(url);
      setLinkCopied(true);
      setTimeout(() => setLinkCopied(false), 2000);
    } catch {
      setShareUrl(url);
    }
  };

  const copyShareUrlInput = () => {
    if (!shareUrl) return;
    navigator.clipboard.writeText(shareUrl);
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
        onClick={copyShareLink}
        disabled={!results}
        title={
          results
            ? "Create a public, read-only link to this readout (expires in 30 days)"
            : "Analysis results are required before a readout can be shared"
        }
        className="px-3 py-1.5 text-xs font-medium text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-indigo-50"
      >
        {linkCopied ? "Link copied ✓" : "Copy share link"}
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
      {shareUrl && (
        <div className="flex items-center gap-1.5">
          <input
            type="text"
            readOnly
            value={shareUrl}
            onFocus={(e) => e.currentTarget.select()}
            className="px-2 py-1.5 text-xs text-gray-700 bg-white border border-gray-300 rounded-lg w-64"
          />
          <button
            onClick={copyShareUrlInput}
            className="px-3 py-1.5 text-xs font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Copy
          </button>
        </div>
      )}
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
}
