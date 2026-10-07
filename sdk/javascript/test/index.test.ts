import { describe, expect, it } from "vitest";
import { SDK_VERSION, isBatchAssignmentError } from "../src/index";

describe("package smoke", () => {
  it("exposes the SDK version", () => {
    expect(SDK_VERSION).toBe("0.1.0");
  });

  it("distinguishes batch assignment errors", () => {
    expect(isBatchAssignmentError({ experimentKey: "x", error: "experiment_not_found" })).toBe(true);
    expect(
      isBatchAssignmentError({
        experimentKey: "x",
        experimentId: "e",
        variantKey: "control",
        variantId: "v",
        isControl: true,
        enrolled: true,
      }),
    ).toBe(false);
  });
});
