/**
 * Client-side experiment readout: builds a self-contained, print-friendly
 * HTML summary from data already loaded in the browser (experiment +
 * analysis results), so a PM can hand stakeholders a document without any
 * backend export work. Download via `downloadReadout`.
 */
import { triggerBlobDownload } from "./api";
import type { AnalysisResults, Experiment, MetricResult, VariantStats } from "./types";

export interface Decision {
  state: "ship" | "do_not_ship" | "keep_collecting" | "no_effect";
  headline: string;
  detail: string;
}

function findPrimaryMetric(results: AnalysisResults): MetricResult | undefined {
  return results.metrics.find((m) => m.role === "primary");
}

function resolveWinnerName(experiment: Experiment, metric: MetricResult): string {
  const winningVariant = metric.recommendation?.winning_variant;
  if (winningVariant) {
    const match = experiment.variants.find(
      (v) => v.key === winningVariant || v.name === winningVariant || v.id === winningVariant,
    );
    if (match) return match.name;
    return winningVariant;
  }

  const fallback = experiment.variants.find((v) => !v.is_control);
  return fallback?.name ?? "the treatment variant";
}

function breachedMetricNames(results: AnalysisResults): string[] {
  const fromList = results.guardrail_breaches ?? [];
  const fromMetrics = results.metrics
    .filter((m) => m.guardrail_status?.is_breached)
    .map((m) => m.metric_key);
  return Array.from(new Set([...fromList, ...fromMetrics]));
}

/**
 * Translates a primary metric's statistical result into a plain-language
 * ship / hold / keep-collecting recommendation. Presentation only — derives
 * no new statistics, just reads what the statistical engine already computed.
 */
export function deriveDecision(experiment: Experiment, results: AnalysisResults): Decision | null {
  const primary = findPrimaryMetric(results);
  const freq = primary?.frequentist;
  if (!primary || !freq) return null;

  const breached = breachedMetricNames(results);
  if (breached.length > 0) {
    return {
      state: "do_not_ship",
      headline: "Do not ship",
      detail: `Guardrail breach on ${breached.join(", ")}.`,
    };
  }

  if (freq.is_significant) {
    if (freq.effect_size.relative > 0) {
      const winner = resolveWinnerName(experiment, primary);
      return {
        state: "ship",
        headline: `Ship ${winner}`,
        detail: `${primary.metric_key} improved by ${pct(freq.effect_size.relative, 1)} (p=${freq.p_value.toFixed(3)}), with no guardrail breaches.`,
      };
    }

    return {
      state: "do_not_ship",
      headline: "Do not ship",
      detail: `The primary metric regressed significantly (p=${freq.p_value.toFixed(3)}).`,
    };
  }

  const ssc = primary.sample_size_calculation;
  const underpowered = ssc ? ssc.is_sufficient === false : freq.power_achieved < 0.8;

  if (underpowered) {
    const sampleDetail = ssc
      ? ` Collected ${ssc.current_total.toLocaleString()} of ${ssc.minimum_required.toLocaleString()} required samples.`
      : ` Statistical power is ${Math.round(freq.power_achieved * 100)}%, below the 80% target.`;
    return {
      state: "keep_collecting",
      headline: "Keep collecting data",
      detail: `Not enough data yet to reach a confident conclusion.${sampleDetail}`,
    };
  }

  return {
    state: "no_effect",
    headline: "No detectable effect",
    detail: `${primary.metric_key} shows no statistically significant difference, and the experiment has adequate statistical power.`,
  };
}

function decisionBannerHtml(decision: Decision | null): string {
  if (!decision) return "";

  return `<section class="decision ${decision.state}">
    <p class="decision-label">Recommendation</p>
    <p class="decision-headline">${esc(decision.headline)}</p>
    <p class="decision-detail">${esc(decision.detail)}</p>
  </section>`;
}

function esc(value: unknown): string {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function pct(value: number | undefined | null, digits = 2): string {
  return value == null ? "—" : `${(value * 100).toFixed(digits)}%`;
}

function variantRows(experiment: Experiment, metric: MetricResult): string {
  const statsByKey = new Map<string, VariantStats>(
    (metric.variants ?? []).map((v) => [v.variant_key, v]),
  );
  const control = metric.variants?.find((v) =>
    experiment.variants.some((ev) => ev.key === v.variant_key && ev.is_control),
  );

  return experiment.variants
    .map((variant) => {
      const stats = statsByKey.get(variant.key);
      const lift =
        stats?.conversion_rate != null && control?.conversion_rate
          ? (stats.conversion_rate - control.conversion_rate) / control.conversion_rate
          : null;

      return `<tr>
        <td>${esc(variant.name)}${variant.is_control ? " <em>(control)</em>" : ""}</td>
        <td class="num">${stats?.sample_size?.toLocaleString() ?? "—"}</td>
        <td class="num">${stats?.conversions?.toLocaleString() ?? "—"}</td>
        <td class="num">${pct(stats?.conversion_rate)}</td>
        <td class="num">${variant.is_control || lift == null ? "—" : pct(lift)}</td>
      </tr>`;
    })
    .join("\n");
}

function metricSection(experiment: Experiment, metric: MetricResult): string {
  const freq = metric.frequentist;
  const guardrail = metric.guardrail_status;

  const verdict = guardrail
    ? guardrail.is_breached
      ? `<span class="badge bad">Guardrail breached</span>`
      : `<span class="badge ok">Guardrail holding</span>`
    : freq
      ? freq.is_significant
        ? `<span class="badge good">Statistically significant</span>`
        : `<span class="badge">Not significant</span>`
      : `<span class="badge">Insufficient data</span>`;

  const statsBlock = freq
    ? `<dl>
        <div><dt>p-value</dt><dd>${freq.p_value.toFixed(4)}</dd></div>
        <div><dt>Effect (relative)</dt><dd>${pct(freq.effect_size.relative)}</dd></div>
        <div><dt>${Math.round(freq.confidence_level * 100)}% CI</dt>
          <dd>${pct(freq.confidence_interval.lower)} to ${pct(freq.confidence_interval.upper)}</dd></div>
        <div><dt>Power achieved</dt><dd>${pct(freq.power_achieved, 1)}</dd></div>
      </dl>`
    : "";

  return `<section>
    <h2>${esc(metric.metric_key)} <small>(${esc(metric.role)})</small> ${verdict}</h2>
    <table>
      <thead><tr><th>Variant</th><th class="num">Sample size</th><th class="num">Conversions</th><th class="num">Rate</th><th class="num">Lift</th></tr></thead>
      <tbody>${variantRows(experiment, metric)}</tbody>
    </table>
    ${statsBlock}
    ${metric.recommendation ? `<p class="note">${esc(metric.recommendation.message)}</p>` : ""}
  </section>`;
}

export function buildReadoutHtml(experiment: Experiment, results?: AnalysisResults): string {
  const generated = new Date().toLocaleString();
  const conclusion =
    experiment.status === "concluded"
      ? `<section>
          <h2>Conclusion</h2>
          <p><strong>${esc(experiment.conclusion_decision ?? "")}</strong></p>
          ${experiment.conclusion_rationale ? `<p>${esc(experiment.conclusion_rationale)}</p>` : ""}
        </section>`
      : "";

  const decision = results ? deriveDecision(experiment, results) : null;
  const decisionBanner = decisionBannerHtml(decision);

  const metricSections = results?.metrics?.length
    ? results.metrics.map((metric) => metricSection(experiment, metric)).join("\n")
    : `<section><p class="note">No analysis results are available yet for this experiment.</p></section>`;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>${esc(experiment.name)} — Experiment Readout</title>
<style>
  body { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; color: #1a202c; max-width: 760px; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; }
  h1 { margin-bottom: 0.25rem; }
  h2 { margin-top: 2rem; border-bottom: 1px solid #e2e8f0; padding-bottom: 0.35rem; font-size: 1.1rem; }
  h2 small { color: #718096; font-weight: normal; }
  .meta { color: #718096; font-size: 0.85rem; }
  .badge { display: inline-block; font-size: 0.7rem; padding: 0.15rem 0.55rem; border-radius: 999px; background: #edf2f7; color: #4a5568; vertical-align: middle; margin-left: 0.5rem; }
  .badge.good { background: #c6f6d5; color: #22543d; }
  .badge.ok { background: #c6f6d5; color: #22543d; }
  .badge.bad { background: #fed7d7; color: #822727; }
  table { border-collapse: collapse; width: 100%; margin: 0.75rem 0; font-size: 0.9rem; }
  th, td { text-align: left; padding: 0.4rem 0.6rem; border-bottom: 1px solid #edf2f7; }
  th.num, td.num { text-align: right; }
  dl { display: flex; flex-wrap: wrap; gap: 1.5rem; font-size: 0.9rem; margin: 0.75rem 0; }
  dt { color: #718096; font-size: 0.75rem; text-transform: uppercase; }
  dd { margin: 0; font-weight: 600; }
  .note { font-size: 0.9rem; color: #4a5568; background: #f7fafc; border-left: 3px solid #cbd5e0; padding: 0.5rem 0.75rem; }
  .decision { margin: 1.25rem 0; padding: 1rem 1.25rem; border-radius: 0.5rem; border-left: 4px solid; }
  .decision-label { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.03em; margin: 0 0 0.25rem; opacity: 0.8; }
  .decision-headline { font-size: 1.15rem; font-weight: 700; margin: 0 0 0.25rem; }
  .decision-detail { font-size: 0.9rem; margin: 0; }
  .decision.ship { background: #c6f6d5; border-color: #38a169; color: #22543d; }
  .decision.do_not_ship { background: #fed7d7; border-color: #e53e3e; color: #822727; }
  .decision.keep_collecting { background: #feebc8; border-color: #dd6b20; color: #7b341e; }
  .decision.no_effect { background: #edf2f7; border-color: #a0aec0; color: #4a5568; }
  @media print { body { margin: 0.5rem auto; } }
</style>
</head>
<body>
<h1>${esc(experiment.name)}</h1>
<p class="meta">${esc(experiment.key)} · status: ${esc(experiment.status)} · readout generated ${esc(generated)}</p>
${experiment.hypothesis ? `<p><strong>Hypothesis:</strong> ${esc(experiment.hypothesis)}</p>` : ""}
${decisionBanner}
${conclusion}
${metricSections}
<p class="meta">Generated by ExperimentHub${results ? ` from analysis computed at ${esc(new Date(results.computed_at).toLocaleString())}` : ""}.</p>
</body>
</html>`;
}

export function downloadReadout(experiment: Experiment, results?: AnalysisResults): void {
  const html = buildReadoutHtml(experiment, results);
  const blob = new Blob([html], { type: "text/html;charset=utf-8" });
  triggerBlobDownload(blob, `${experiment.key}-readout.html`);
}
