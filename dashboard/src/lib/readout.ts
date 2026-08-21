/**
 * Client-side experiment readout: builds a self-contained, print-friendly
 * HTML summary from data already loaded in the browser (experiment +
 * analysis results), so a PM can hand stakeholders a document without any
 * backend export work. Download via `downloadReadout`.
 */
import { triggerBlobDownload } from "./api";
import type { AnalysisResults, Experiment, MetricResult, VariantStats } from "./types";

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
  @media print { body { margin: 0.5rem auto; } }
</style>
</head>
<body>
<h1>${esc(experiment.name)}</h1>
<p class="meta">${esc(experiment.key)} · status: ${esc(experiment.status)} · readout generated ${esc(generated)}</p>
${experiment.hypothesis ? `<p><strong>Hypothesis:</strong> ${esc(experiment.hypothesis)}</p>` : ""}
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
