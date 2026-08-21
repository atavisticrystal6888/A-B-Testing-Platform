/**
 * Sample Ratio Mismatch (SRM) diagnostics.
 *
 * Pure, dependency-free chi-square goodness-of-fit test used to detect when
 * the observed traffic split across variants diverges from the configured
 * allocation by more than chance would explain.
 */

const ITMAX = 200;
const EPS = 3e-7;
const FPMIN = 1e-300;

/** Lanczos approximation of ln(Gamma(x)) for x > 0. */
function logGamma(xx: number): number {
  const cof = [
    76.18009172947146,
    -86.50532032941677,
    24.01409824083091,
    -1.231739572450155,
    0.1208650973866179e-2,
    -0.5395239384953e-5,
  ];
  let x = xx;
  let y = xx;
  let tmp = x + 5.5;
  tmp -= (x + 0.5) * Math.log(tmp);
  let ser = 1.000000000190015;
  for (let j = 0; j < 6; j++) {
    y += 1;
    ser += cof[j] / y;
  }
  return -tmp + Math.log((2.5066282746310005 * ser) / x);
}

/** Regularized lower incomplete gamma P(a, x) via series expansion. */
function gammaSeriesP(a: number, x: number): number {
  if (x <= 0) return 0;
  const gln = logGamma(a);
  let ap = a;
  let sum = 1 / a;
  let del = sum;
  for (let n = 1; n <= ITMAX; n++) {
    ap += 1;
    del *= x / ap;
    sum += del;
    if (Math.abs(del) < Math.abs(sum) * EPS) break;
  }
  return sum * Math.exp(-x + a * Math.log(x) - gln);
}

/** Regularized upper incomplete gamma Q(a, x) via Lentz's continued fraction. */
function gammaContinuedFractionQ(a: number, x: number): number {
  const gln = logGamma(a);
  let b = x + 1 - a;
  let c = 1 / FPMIN;
  let d = 1 / b;
  let h = d;
  for (let i = 1; i <= ITMAX; i++) {
    const an = -i * (i - a);
    b += 2;
    d = an * d + b;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    c = b + an / c;
    if (Math.abs(c) < FPMIN) c = FPMIN;
    d = 1 / d;
    const del = d * c;
    h *= del;
    if (Math.abs(del - 1) < EPS) break;
  }
  return Math.exp(-x + a * Math.log(x) - gln) * h;
}

/** Regularized upper incomplete gamma Q(a, x) = 1 - P(a, x). */
function gammaQ(a: number, x: number): number {
  if (x < 0 || a <= 0) return NaN;
  if (x === 0) return 1;
  if (x < a + 1) {
    return 1 - gammaSeriesP(a, x);
  }
  return gammaContinuedFractionQ(a, x);
}

/**
 * Chi-square survival function: P(X > x) for a chi-square distribution with
 * `df` degrees of freedom, computed as the regularized upper incomplete
 * gamma Q(df/2, x/2).
 */
export function chiSquareSf(x: number, df: number): number {
  if (x <= 0) return 1;
  return gammaQ(df / 2, x / 2);
}

export const SRM_P_THRESHOLD = 0.001;

/**
 * Chi-square goodness-of-fit test for sample ratio mismatch.
 *
 * `observed` are the per-variant observed sample sizes; `expectedWeights`
 * are the configured allocation weights for the same variants (e.g. basis
 * points), normalized here over whichever variants are present since
 * allocations may not sum to 10000 under a partial rollout.
 *
 * Returns null when there is not yet enough data to call SRM: any expected
 * count under 5, or fewer than 100 total observed samples.
 */
export function computeSrm(
  observed: number[],
  expectedWeights: number[],
): { chi2: number; pValue: number; observed: number[]; expected: number[] } | null {
  if (observed.length !== expectedWeights.length || observed.length < 2) return null;

  const totalObserved = observed.reduce((sum, n) => sum + n, 0);
  const totalWeight = expectedWeights.reduce((sum, w) => sum + w, 0);
  if (totalObserved < 100 || totalWeight <= 0) return null;

  const expected = expectedWeights.map((w) => (w / totalWeight) * totalObserved);
  if (expected.some((e) => e < 5)) return null;

  const chi2 = observed.reduce((sum, o, i) => {
    const e = expected[i];
    return sum + ((o - e) * (o - e)) / e;
  }, 0);

  const df = observed.length - 1;
  const pValue = chiSquareSf(chi2, df);

  return { chi2, pValue, observed, expected };
}
