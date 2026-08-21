import { describe, expect, it } from "vitest";

import { deriveDecision } from "../../src/lib/readout";
import type { AnalysisResults, Experiment, MetricResult } from "../../src/lib/types";

function exp({ variants }: { variants: string[] }): Experiment {
  return {
    id: "exp-1",
    key: "exp-key",
    name: "Test Experiment",
    hypothesis: "Test hypothesis",
    status: "running",
    version: 1,
    archived: false,
    variants: variants.map((name, i) => ({
      id: `variant-${i}`,
      key: name,
      name,
      is_control: i === 0,
      traffic_allocation: Math.round(100 / variants.length),
      sort_order: i,
    })),
    inserted_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
  };
}

function results({
  p_value,
  relative,
  is_sufficient,
  breaches = [],
  power_achieved = 0.9,
  current_total = 4000,
  minimum_required = 10000,
  noFrequentist = false,
  noPrimary = false,
  extraMetrics = [],
}: {
  p_value?: number;
  relative?: number;
  is_sufficient?: boolean;
  breaches?: string[];
  power_achieved?: number;
  current_total?: number;
  minimum_required?: number;
  noFrequentist?: boolean;
  noPrimary?: boolean;
  extraMetrics?: MetricResult[];
}): AnalysisResults {
  const primary: MetricResult = {
    metric_key: "signup_rate",
    role: "primary",
    frequentist: noFrequentist
      ? undefined
      : {
          test_method: "welch_t_test",
          p_value: p_value ?? 0.5,
          confidence_level: 0.95,
          confidence_interval: { lower: 0, upper: 0, point_estimate: 0 },
          effect_size: { absolute: 0, relative: relative ?? 0 },
          power_achieved,
          is_significant: (p_value ?? 0.5) < 0.05,
        },
    sample_size_calculation:
      is_sufficient == null
        ? undefined
        : {
            minimum_required,
            current_total,
            is_sufficient,
            power: 0.8,
            significance_level: 0.05,
          },
  };

  return {
    experiment_id: "exp-1",
    computed_at: "2026-01-01T00:00:00Z",
    computation_time_ms: 10,
    metrics: noPrimary ? [...extraMetrics] : [primary, ...extraMetrics],
    overall_status: "completed",
    has_sufficient_data: true,
    guardrail_breaches: breaches,
  };
}

describe("deriveDecision", () => {
  it("maps significant improvement + clean guardrails to ship", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({ p_value: 0.01, relative: 0.12, is_sufficient: true, breaches: [] }),
    );
    expect(d).toMatchObject({ state: "ship" });
    expect(d!.headline).toContain("variant-b");
  });

  it("maps a guardrail breach listed on results.guardrail_breaches to do_not_ship", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({ p_value: 0.01, relative: 0.12, is_sufficient: true, breaches: ["signup_rate"] }),
    );
    expect(d).toMatchObject({ state: "do_not_ship", headline: "Do not ship" });
    expect(d!.detail).toContain("signup_rate");
  });

  it("maps a per-metric guardrail_status breach to do_not_ship even when guardrail_breaches is empty", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({
        p_value: 0.01,
        relative: 0.12,
        is_sufficient: true,
        breaches: [],
        extraMetrics: [
          {
            metric_key: "error_rate",
            role: "guardrail",
            guardrail_status: { threshold: 0.05, direction: "below", current_value: 0.08, is_breached: true },
          },
        ],
      }),
    );
    expect(d).toMatchObject({ state: "do_not_ship" });
    expect(d!.detail).toContain("error_rate");
  });

  it("maps a significant negative primary effect with no breach to do_not_ship", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({ p_value: 0.02, relative: -0.15, is_sufficient: true, breaches: [] }),
    );
    expect(d).toMatchObject({ state: "do_not_ship" });
    expect(d!.detail.toLowerCase()).toContain("regressed significantly");
  });

  it("maps not-significant + underpowered (is_sufficient false) to keep_collecting", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({
        p_value: 0.4,
        relative: 0.03,
        is_sufficient: false,
        current_total: 2500,
        minimum_required: 8000,
      }),
    );
    expect(d).toMatchObject({ state: "keep_collecting" });
    expect(d!.detail).toContain("2,500");
    expect(d!.detail).toContain("8,000");
  });

  it("maps not-significant + no sample_size_calculation but power_achieved < 0.8 to keep_collecting", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({ p_value: 0.4, relative: 0.03, power_achieved: 0.55 }),
    );
    expect(d).toMatchObject({ state: "keep_collecting" });
  });

  it("maps not-significant + adequately powered to no_effect", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({ p_value: 0.6, relative: 0.01, is_sufficient: true, power_achieved: 0.9 }),
    );
    expect(d).toMatchObject({ state: "no_effect", headline: "No detectable effect" });
  });

  it("returns null when there is no primary metric result", () => {
    const d = deriveDecision(exp({ variants: ["control", "variant-b"] }), results({ noPrimary: true }));
    expect(d).toBeNull();
  });

  it("returns null when the primary metric has no frequentist block", () => {
    const d = deriveDecision(
      exp({ variants: ["control", "variant-b"] }),
      results({ noFrequentist: true }),
    );
    expect(d).toBeNull();
  });
});
