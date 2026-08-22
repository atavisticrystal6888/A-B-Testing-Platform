import { describe, expect, it } from "vitest";

import { evaluateChecklist } from "../../src/lib/launchChecklist";
import type { Experiment, ExperimentTimeline, Variant } from "../../src/lib/types";

function variant(overrides: Partial<Variant> & { key: string; traffic_allocation: number }): Variant {
  return {
    id: `variant-${overrides.key}`,
    name: overrides.key,
    is_control: false,
    sort_order: 0,
    ...overrides,
  };
}

function exp({
  variants,
  hasPrimaryMetric = true,
}: {
  variants: Variant[];
  hasPrimaryMetric?: boolean;
}): Experiment {
  return {
    id: "exp-1",
    key: "exp-key",
    name: "Test Experiment",
    hypothesis: "Test hypothesis",
    status: "draft",
    version: 1,
    archived: false,
    variants,
    metrics: hasPrimaryMetric
      ? [{ id: "m-1", key: "signup_rate", role: "primary" }]
      : [{ id: "m-2", key: "click_rate", role: "secondary" }],
    inserted_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
  };
}

const evenVariants = [
  variant({ key: "control", traffic_allocation: 5000, is_control: true }),
  variant({ key: "treatment", traffic_allocation: 5000 }),
];

function utcDateString(offsetDays: number): string {
  const now = new Date();
  const d = new Date(now.getTime() + offsetDays * 24 * 60 * 60 * 1000);
  return d.toISOString().slice(0, 10);
}

function timelineWithExposureOn(...dates: string[]): ExperimentTimeline {
  return {
    lifecycle: [],
    daily_exposures: dates.map((date) => ({ date, count: 10 })),
  };
}

describe("evaluateChecklist", () => {
  it("returns pass for every check when everything is healthy", () => {
    const items = evaluateChecklist(
      exp({ variants: evenVariants }),
      timelineWithExposureOn(utcDateString(0)),
    );

    expect(items.map((i) => i.status)).toEqual(["pass", "pass", "pass"]);
    expect(items.map((i) => i.key)).toEqual(["primary_metric", "allocation", "exposures"]);
  });

  describe("primary_metric check", () => {
    it("passes when a primary-role metric is attached", () => {
      const items = evaluateChecklist(exp({ variants: evenVariants, hasPrimaryMetric: true }));
      const item = items.find((i) => i.key === "primary_metric")!;
      expect(item.status).toBe("pass");
    });

    it("fails when no primary-role metric is attached", () => {
      const items = evaluateChecklist(exp({ variants: evenVariants, hasPrimaryMetric: false }));
      const item = items.find((i) => i.key === "primary_metric")!;
      expect(item.status).toBe("fail");
    });

    it("fails when the experiment has no metrics at all", () => {
      const experiment = exp({ variants: evenVariants });
      experiment.metrics = [];
      const item = evaluateChecklist(experiment).find((i) => i.key === "primary_metric")!;
      expect(item.status).toBe("fail");
    });
  });

  describe("allocation check", () => {
    it("passes when variant traffic_allocation sums to exactly 10000", () => {
      const item = evaluateChecklist(exp({ variants: evenVariants })).find(
        (i) => i.key === "allocation",
      )!;
      expect(item.status).toBe("pass");
    });

    it("fails when variant traffic_allocation sums to 9000", () => {
      const variants = [
        variant({ key: "control", traffic_allocation: 4000, is_control: true }),
        variant({ key: "treatment", traffic_allocation: 5000 }),
      ];
      const item = evaluateChecklist(exp({ variants })).find((i) => i.key === "allocation")!;
      expect(item.status).toBe("fail");
    });

    it("fails when variant traffic_allocation sums above 10000", () => {
      const variants = [
        variant({ key: "control", traffic_allocation: 6000, is_control: true }),
        variant({ key: "treatment", traffic_allocation: 5000 }),
      ];
      const item = evaluateChecklist(exp({ variants })).find((i) => i.key === "allocation")!;
      expect(item.status).toBe("fail");
    });
  });

  describe("exposures check", () => {
    it("is unknown when no timeline data is available", () => {
      const item = evaluateChecklist(exp({ variants: evenVariants })).find(
        (i) => i.key === "exposures",
      )!;
      expect(item.status).toBe("unknown");
    });

    it("passes when an exposure entry is dated today", () => {
      const item = evaluateChecklist(
        exp({ variants: evenVariants }),
        timelineWithExposureOn(utcDateString(0)),
      ).find((i) => i.key === "exposures")!;
      expect(item.status).toBe("pass");
    });

    it("passes when an exposure entry is dated yesterday", () => {
      const item = evaluateChecklist(
        exp({ variants: evenVariants }),
        timelineWithExposureOn(utcDateString(-1)),
      ).find((i) => i.key === "exposures")!;
      expect(item.status).toBe("pass");
    });

    it("fails when timeline data exists but has no recent entry", () => {
      const item = evaluateChecklist(
        exp({ variants: evenVariants }),
        timelineWithExposureOn(utcDateString(-10), utcDateString(-5)),
      ).find((i) => i.key === "exposures")!;
      expect(item.status).toBe("fail");
    });

    it("fails when timeline data exists but daily_exposures is empty", () => {
      const item = evaluateChecklist(
        exp({ variants: evenVariants }),
        timelineWithExposureOn(),
      ).find((i) => i.key === "exposures")!;
      expect(item.status).toBe("fail");
    });
  });
});
