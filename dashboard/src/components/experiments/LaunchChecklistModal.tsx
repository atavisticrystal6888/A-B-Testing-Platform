import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../../lib/api";
import { evaluateChecklist, type ChecklistStatus } from "../../lib/launchChecklist";
import type { Experiment, ExperimentTimeline } from "../../lib/types";

interface LaunchChecklistModalProps {
  experiment: Experiment;
  isPending?: boolean;
  errorMessage?: string;
  onConfirm: () => void;
  onCancel: () => void;
}

const STATUS_ICON: Record<ChecklistStatus, string> = {
  pass: "✓",
  fail: "✗",
  unknown: "?",
};

const STATUS_ICON_STYLES: Record<ChecklistStatus, string> = {
  pass: "text-green-600",
  fail: "text-red-600",
  unknown: "text-gray-400",
};

export function LaunchChecklistModal({
  experiment,
  isPending = false,
  errorMessage,
  onConfirm,
  onCancel,
}: LaunchChecklistModalProps) {
  const [confirmingOverride, setConfirmingOverride] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);

  const { data: timelineResponse } = useQuery<{ data: ExperimentTimeline }>({
    queryKey: ["timeline", experiment.id],
    queryFn: () =>
      api.get<{ data: ExperimentTimeline }>(`/api/v1/experiments/${experiment.id}/timeline`),
  });

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

  const items = evaluateChecklist(experiment, timelineResponse?.data);
  const hasFail = items.some((item) => item.status === "fail");
  const unmetCount = items.filter((item) => item.status !== "pass").length;
  const overrideLabel = `Start with ${unmetCount} unmet check${unmetCount === 1 ? "" : "s"}?`;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="launch-checklist-modal-title"
        className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden"
      >
        <div className="px-6 py-5 border-b border-gray-100">
          <h2 id="launch-checklist-modal-title" className="text-lg font-semibold text-gray-900">Launch Checklist</h2>
          <p className="text-sm text-gray-500 mt-1">{experiment.name}</p>
        </div>

        <div className="px-6 py-5">
          <ul className="space-y-3">
            {items.map((item) => (
              <li key={item.key} className="flex items-start gap-3">
                <span
                  className={`mt-0.5 text-sm font-semibold ${STATUS_ICON_STYLES[item.status]}`}
                  aria-hidden="true"
                >
                  {STATUS_ICON[item.status]}
                </span>
                <div>
                  <p className="text-sm font-medium text-gray-900">{item.label}</p>
                  <p className="text-xs text-gray-500">
                    {item.status === "unknown" ? "Couldn't verify" : item.detail}
                  </p>
                </div>
              </li>
            ))}
          </ul>

          {errorMessage && (
            <p className="mt-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
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

          {hasFail && (
            <button
              type="button"
              onClick={() => (confirmingOverride ? onConfirm() : setConfirmingOverride(true))}
              disabled={isPending}
              className="px-4 py-2 text-sm font-medium text-amber-700 bg-amber-50 border border-amber-200 rounded-lg hover:bg-amber-100 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {isPending ? "Starting..." : confirmingOverride ? overrideLabel : "Start anyway"}
            </button>
          )}

          <button
            type="button"
            onClick={onConfirm}
            disabled={hasFail || isPending}
            className="px-4 py-2 text-sm font-medium text-white bg-green-600 rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isPending ? "Starting..." : "Start experiment"}
          </button>
        </div>
      </div>
    </div>
  );
}
