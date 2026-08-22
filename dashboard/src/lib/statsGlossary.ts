export type StatsTerm = "p_value" | "credible_interval" | "power" | "guardrail";

interface GlossaryEntry {
  term: string;
  definition: string;
}

/**
 * Plain-English definitions for the statistical concepts surfaced on the
 * results card (Roadmap #12). Consumed by <InfoTip> and the "How to read
 * this" panel.
 */
export const GLOSSARY: Record<StatsTerm, GlossaryEntry> = {
  p_value: {
    term: "p-value",
    definition:
      "the probability of seeing a difference this large if the variants truly performed the same — lower means stronger evidence",
  },
  credible_interval: {
    term: "credible interval",
    definition: "the range the true effect falls in with 95% probability, given the data",
  },
  power: {
    term: "power",
    definition:
      "the chance this experiment would detect a real effect of the target size — 80%+ is the convention",
  },
  guardrail: {
    term: "guardrail",
    definition: "a metric that must not regress; a breach blocks shipping regardless of the primary result",
  },
};
