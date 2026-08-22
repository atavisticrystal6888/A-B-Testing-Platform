/**
 * Pre-start launch checklist (Roadmap #8).
 *
 * Detectable pre-flight signals only — this is not a full readiness audit.
 * Schedule sanity isn't checked directly: a missing primary metric or a
 * mis-summed allocation are the failure modes that actually block a
 * meaningful start, so they stand in for that broader "is this ready"
 * question. The exposures check is advisory: recent-exposure data may be
 * genuinely unavailable (fresh experiment, timeline endpoint down) without
 * that meaning anything is wrong, so it reports "unknown" rather than
 * "fail" and never blocks a start on its own.
 */
import type { Experiment, ExperimentTimeline } from "./types";

export type ChecklistStatus = "pass" | "fail" | "unknown";

export interface ChecklistItem {
  key: "primary_metric" | "allocation" | "exposures";
  label: string;
  status: ChecklistStatus;
  detail: string;
}

const REQUIRED_ALLOCATION_TOTAL = 10000;

function utcDateString(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function isTodayOrYesterday(dateStr: string, now: Date): boolean {
  const today = utcDateString(now);
  const yesterday = utcDateString(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  return dateStr === today || dateStr === yesterday;
}

function evaluatePrimaryMetric(experiment: Experiment): ChecklistItem {
  const hasPrimary = (experiment.metrics ?? []).some((metric) => metric.role === "primary");
  return {
    key: "primary_metric",
    label: "Primary metric attached",
    status: hasPrimary ? "pass" : "fail",
    detail: hasPrimary
      ? "A primary metric is attached to this experiment."
      : "No primary metric is attached. Attach one before starting.",
  };
}

function evaluateAllocation(experiment: Experiment): ChecklistItem {
  const total = experiment.variants.reduce((sum, variant) => sum + variant.traffic_allocation, 0);
  const isValid = total === REQUIRED_ALLOCATION_TOTAL;
  return {
    key: "allocation",
    label: "Traffic allocation sums to 100%",
    status: isValid ? "pass" : "fail",
    detail: isValid
      ? "Variant traffic allocations sum to 100%."
      : `Variant traffic allocations sum to ${(total / 100).toFixed(2)}%, not 100%.`,
  };
}

function evaluateExposures(timeline: ExperimentTimeline | undefined, now: Date): ChecklistItem {
  if (!timeline) {
    return {
      key: "exposures",
      label: "Recent exposure activity",
      status: "unknown",
      detail: "Couldn't verify — exposure timeline data is unavailable.",
    };
  }

  const hasRecentExposure = timeline.daily_exposures.some((entry) =>
    isTodayOrYesterday(entry.date, now),
  );

  return {
    key: "exposures",
    label: "Recent exposure activity",
    status: hasRecentExposure ? "pass" : "fail",
    detail: hasRecentExposure
      ? "Exposure events were observed today or yesterday."
      : "No exposure events observed today or yesterday.",
  };
}

export function evaluateChecklist(
  experiment: Experiment,
  timeline?: ExperimentTimeline,
): ChecklistItem[] {
  return [
    evaluatePrimaryMetric(experiment),
    evaluateAllocation(experiment),
    evaluateExposures(timeline, new Date()),
  ];
}
