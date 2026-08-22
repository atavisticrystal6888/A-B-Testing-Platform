import { useEffect, useRef, useState } from "react";
import type { ConclusionDecision, Variant } from "../../lib/types";

interface ConcludeModalProps {
  experimentName: string;
  variants: Variant[];
  isPending?: boolean;
  errorMessage?: string;
  onConfirm: (decision: ConclusionDecision, rationale: string, winnerVariantId?: string) => void;
  onCancel: () => void;
}

export function ConcludeModal({
  experimentName,
  variants,
  isPending = false,
  errorMessage,
  onConfirm,
  onCancel,
}: ConcludeModalProps) {
  const [decision, setDecision] = useState<ConclusionDecision | "">("");
  const [rationale, setRationale] = useState("");
  const [winnerVariantId, setWinnerVariantId] = useState("");
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const firstFocusable = panelRef.current?.querySelector<HTMLElement>(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    );
    firstFocusable?.focus();
  }, []);

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        onCancel();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, [onCancel]);

  const decisions = [
    { value: "ship_variant", label: "Ship Variant", description: "Roll out the winning variant to all users" },
    { value: "revert_to_control", label: "Revert to Control", description: "Keep the current control experience" },
    { value: "inconclusive", label: "Inconclusive", description: "Results are not statistically significant" },
  ] satisfies Array<{ value: ConclusionDecision; label: string; description: string }>;

  const canConfirm = Boolean(decision && rationale.trim() && (decision !== "ship_variant" || winnerVariantId));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="conclude-modal-title"
        className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden"
      >
        <div className="px-6 py-5 border-b border-gray-100">
          <h2 id="conclude-modal-title" className="text-lg font-semibold text-gray-900">Conclude Experiment</h2>
          <p className="text-sm text-gray-500 mt-1">{experimentName}</p>
        </div>

        <div className="px-6 py-5 space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Decision</label>
            <div className="space-y-2">
              {decisions.map((d) => (
                <label
                  key={d.value}
                  className={`flex items-start p-3 rounded-lg border-2 cursor-pointer transition-all ${
                    decision === d.value
                      ? 'border-indigo-500 bg-indigo-50'
                      : 'border-gray-200 hover:border-gray-300'
                  }`}
                >
                  <input
                    type="radio"
                    name="decision"
                    value={d.value}
                    checked={decision === d.value}
                    onChange={(e) => setDecision(e.target.value as ConclusionDecision)}
                    className="mt-0.5 mr-3"
                  />
                  <div>
                    <p className="text-sm font-medium text-gray-900">{d.label}</p>
                    <p className="text-xs text-gray-500">{d.description}</p>
                  </div>
                </label>
              ))}
            </div>
          </div>

          {decision === "ship_variant" && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Winning Variant
              </label>
              <select
                value={winnerVariantId}
                onChange={(e) => setWinnerVariantId(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="">Select a variant</option>
                {variants.map((variant) => (
                  <option key={variant.id} value={variant.id}>
                    {variant.name} ({variant.key})
                  </option>
                ))}
              </select>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Rationale</label>
            <textarea
              value={rationale}
              onChange={(e) => setRationale(e.target.value)}
              rows={3}
              placeholder="Explain the reasoning behind this decision..."
              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          {errorMessage && (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {errorMessage}
            </p>
          )}
        </div>

        <div className="px-6 py-4 bg-gray-50 flex justify-end gap-3">
          <button
            type="button"
            onClick={onCancel}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => decision && onConfirm(decision, rationale, winnerVariantId || undefined)}
            disabled={!canConfirm || isPending}
            className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isPending ? "Concluding..." : "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}
