import { describe, expect, it } from "vitest";

import { chiSquareSf, computeSrm, SRM_P_THRESHOLD } from "../../src/lib/srm";

describe("chiSquareSf", () => {
  it("matches the classic p=0.05 critical value at df=1", () => {
    expect(chiSquareSf(3.841, 1)).toBeCloseTo(0.05, 3);
  });

  it("matches the classic p=0.001 critical value at df=1", () => {
    expect(chiSquareSf(10.828, 1)).toBeCloseTo(0.001, 3);
  });

  it("matches the classic p=0.001 critical value at df=2", () => {
    expect(chiSquareSf(13.816, 2)).toBeCloseTo(0.001, 3);
  });

  it("returns 1 at x=0 regardless of df", () => {
    expect(chiSquareSf(0, 3)).toBe(1);
  });
});

describe("computeSrm", () => {
  it("returns p ~ 1 when observed matches expected exactly", () => {
    const result = computeSrm([5000, 5000], [5000, 5000]);
    expect(result).not.toBeNull();
    expect(result!.pValue).toBeCloseTo(1, 2);
    expect(result!.chi2).toBeCloseTo(0, 6);
  });

  it("flags a mismatched split with chi2=64 and p well below the threshold", () => {
    const result = computeSrm([5400, 4600], [5000, 5000]);
    expect(result).not.toBeNull();
    expect(result!.chi2).toBeCloseTo(64, 6);
    expect(result!.pValue).toBeLessThan(SRM_P_THRESHOLD);
  });

  it("returns null below the sample-size floor (total observed < 100)", () => {
    const result = computeSrm([30, 30], [5000, 5000]);
    expect(result).toBeNull();
  });

  it("returns null when any expected count is below 5", () => {
    const result = computeSrm([995, 5], [9990, 10]);
    expect(result).toBeNull();
  });

  it("exposes the SRM_P_THRESHOLD constant", () => {
    expect(SRM_P_THRESHOLD).toBe(0.001);
  });
});
