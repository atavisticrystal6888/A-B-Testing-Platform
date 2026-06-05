# Research: ExperimentHub Technical Decisions

**Branch**: `001-experimenthub-spec` | **Date**: 2026-04-01
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

---

## R1: Hash Algorithm for Deterministic Assignment

### Decision: MurmurHash3 (128-bit)

### Rationale
MurmurHash3 provides the best tradeoff of speed, uniformity, and cross-platform availability for user-to-variant assignment.

### Evaluation

| Algorithm | Speed (ns/op) | Uniformity (chi² p-value) | Cross-platform libs | Cryptographic | Notes |
|-----------|---------------|---------------------------|---------------------|---------------|-------|
| **MurmurHash3** | ~15-25 | p > 0.99 on 1M keys | Rust, Python, JS, Elixir, Java, Go | No | Best overall for assignment. Used by Google Optimize, Statsig. |
| SHA-256 | ~200-400 | p > 0.99 (cryptographic uniformity) | Everywhere | Yes | 10-20× slower. Cryptographic security unnecessary for assignment. |
| xxHash (XXH3) | ~5-10 | p > 0.99 | Rust, C, Python, Java | No | Fastest, but fewer WASM/browser implementations. Less battle-tested for experiment assignment. |
| FNV-1a | ~10-15 | p > 0.90 (weaker avalanche) | Everywhere | No | Weaker avalanche effect risks non-uniform distribution on structured input IDs. |
| CityHash | ~10-15 | p > 0.99 | C++, limited others | No | Primarily C++ ecosystem. Not suitable for Rust NIF + WASM target. |

### Algorithm Details
- **Input**: `hash(experiment_id + ":" + user_id)` → 128-bit integer
- **Variant selection**: `hash_value % 10000` gives a bucket 0-9999. Map buckets to variants based on traffic allocation: if variant A is 50% → buckets 0-4999, variant B is 50% → buckets 5000-9999.
- **Mutual exclusion**: For experiments in a mutual exclusion group, hash with `hash(layer_id + ":" + user_id)` to determine the experiment layer slot, then `hash(experiment_id + ":" + user_id)` for variant within the experiment.
- **Monotonic rollout**: For feature flag rollouts, users with `hash_value % 10000 < rollout_percentage * 100` get the feature. Increasing the percentage only adds users, never removes (FR-049).

### Alternatives Rejected
- **SHA-256**: 10-20× slower with no benefit for non-cryptographic assignment. Would jeopardize the 5ms p99 target (NFR-001).
- **xxHash**: Fastest option but limited WASM/browser tooling for the browser SDK. MurmurHash3 has mature `wasm-bindgen` compatible Rust crates.

---

## R2: Bayesian vs Frequentist Statistical Methods

### Decision: Both — Frequentist as primary, Bayesian as supplementary

### Rationale
Providing both methods satisfies different analytical needs (FR-022 through FR-030) and matches what mature experimentation platforms offer. Frequentist methods are the industry default for hypothesis testing; Bayesian methods provide intuitive probability statements useful for business decisions.

### Frequentist Methods (Primary)
| Method | Use Case | Library |
|--------|----------|---------|
| Z-test for proportions | Binary metrics (conversion rates) | scipy.stats.proportions_ztest |
| Welch's t-test | Continuous metrics (revenue, time) | scipy.stats.ttest_ind (equal_var=False) |
| Chi-squared test | Categorical outcomes, uniformity testing | scipy.stats.chi2_contingency |
| Bonferroni / Holm-Šidák | Multiple comparison correction (3+ variants) | statsmodels.stats.multitest |
| O'Brien-Fleming | Sequential analysis / alpha spending | Custom implementation using scipy |

### Bayesian Methods (Supplementary)
| Method | Use Case | Library |
|--------|----------|---------|
| Beta-Binomial conjugate | Binary metrics (fast, closed-form) | scipy.stats.beta (no MCMC needed) |
| Normal-Normal conjugate | Continuous metrics (fast, closed-form) | scipy.stats (no MCMC needed) |
| Thompson Sampling | Probability-to-be-best via simulation | numpy random sampling |

### Key Design Decision: Conjugate Priors Only (No MCMC)
PyMC is listed as a dependency for potential future use, but v1 will use **conjugate prior models only**:
- Beta-Binomial for conversion rates: `Beta(α + successes, β + failures)` with weak prior `Beta(1,1)`
- Normal-Normal for continuous metrics: closed-form posterior with known variance approximation

**Why no MCMC for v1**: Conjugate models compute in <100ms for any sample size. MCMC (PyMC) takes seconds-to-minutes and is unnecessary for standard A/B test analysis. This satisfies NFR-008 (< 30 sec for 1M observations) with massive margin.

### Alternatives Considered
- **Bayesian-only**: Rejected because frequentist p-values remain the industry standard for reporting. Teams migrating from other platforms expect p-values.
- **Frequentist-only**: Rejected because Bayesian probability-to-be-best is more intuitive for PMs ("85% chance B is better") vs p-values ("we reject the null hypothesis at α=0.05").

---

## R3: Kafka Partitioning Strategy

### Decision: Partition by `experiment_id` for event topics; single partition for lifecycle topics

### Rationale
Partitioning events by `experiment_id` ensures all events for a single experiment are ordered and processed by the same consumer, enabling correct incremental aggregation without cross-partition coordination.

### Topic Design

| Topic | Partition Key | Partitions (v1) | Retention | Purpose |
|-------|--------------|-----------------|-----------|---------|
| `experimenthub.events.inbound` | `tenant_id:experiment_id` | 12 | 48 hours | Pre-validation inbound events from REST API (see R11) |
| `experimenthub.events.raw` | `experiment_id` | 12 | 7 days | Validated metric/conversion events |
| `experimenthub.assignments` | `experiment_id` | 12 | 7 days | Assignment events for audit/replay |
| `experimenthub.lifecycle` | `experiment_id` | 3 | 30 days | Experiment state transitions |
| `experimenthub.audit` | `tenant_id` | 3 | 90 days | Audit log events |

### Partition Count Rationale (v1)
- **12 partitions for event topics** (inbound, raw, assignments): Supports up to 12 parallel consumers. At 50K events/sec and ~4K events/sec per consumer, 12 partitions provide headroom. Scales to 10× by adding partitions (Kafka supports this without data loss).
- **3 partitions for lifecycle/audit**: Low volume topics. 3 partitions for minimal redundancy.

### Ordering Guarantees
- Events within a single experiment are ordered (same partition).
- Events across experiments have no ordering guarantee (different partitions) — this is acceptable since statistical analysis is per-experiment.
- Consumer group `experimenthub-data-pipeline` processes events and writes aggregated rollups to PostgreSQL.

### Alternatives Rejected
- **Partition by `user_id`**: Would spread a single experiment's events across all partitions, requiring cross-partition aggregation for experiment results. Much more complex.
- **Partition by `tenant_id`**: Would concentrate all events for a large tenant on one partition, creating hotspots. Experiment-level partitioning distributes load more evenly.
- **Single partition**: No parallelism. Cannot meet 50K events/sec throughput target.

---

## R4: PostgreSQL Partitioning for Event Tables

### Decision: Range partitioning by month on the `events` aggregation table; no partitioning on experiment/config tables

### Rationale
Event data grows continuously and queries typically filter by time range and experiment. Monthly range partitions enable partition pruning for dashboard queries (NFR-003) and efficient data retention (FR-051: 90-day raw retention).

### Partitioning Strategy

| Table | Partitioning | Key | Rationale |
|-------|-------------|-----|-----------|
| `experiment_events_raw` | Range by month | `inserted_at` | 90-day retention via partition drop. Dashboard queries prune to relevant months. |
| `experiment_results_daily` | Range by month | `date` | Aggregated rollups grow over time. Partition pruning for time-range queries. |
| `experiments` | None | — | Low cardinality (100s per tenant). No benefit from partitioning. |
| `audit_logs` | Range by month | `inserted_at` | Grows continuously. Monthly partitions for archival. |
| All others | None | — | Low cardinality configuration tables. |

### Retention Implementation
- Monthly partitions: `experiment_events_raw_2026_01`, `experiment_events_raw_2026_02`, etc.
- Retention enforced by dropping partitions older than 90 days via Oban scheduled job.
- Aggregated results (`experiment_results_daily`) are never dropped (FR-052).

### Indexes
- `experiment_events_raw`: Composite index on `(tenant_id, experiment_id, inserted_at)` — covers the primary query pattern.
- `experiment_results_daily`: Composite index on `(tenant_id, experiment_id, variant_id, date)`.
- RLS policies use `tenant_id` as the partition qualifier within each partition.

### Alternatives Rejected
- **Hash partitioning by experiment_id**: Good for write distribution but prevents efficient time-range queries. Dashboard queries almost always filter by time.
- **No partitioning**: Full table scans on 10M+ rows for retention cleanup. Partition drop is O(1) vs DELETE which generates massive WAL.
- **TimescaleDB**: Adds a dependency for time-series functionality that native PostgreSQL partitioning handles adequately. Violates Article VII (simplicity).

---

## R5: Elixir Broadway vs GenStage vs Manual Kafka Consumer

### Decision: Broadway with BroadwayKafka

### Rationale
Broadway provides built-in batching, back-pressure, graceful shutdown, rate limiting, and fault tolerance — all required for the event collector (FR-016 through FR-021). It's the BEAM ecosystem's standard for data ingestion pipelines.

### Comparison

| Feature | Broadway | GenStage | Manual (brod/kafka_ex) |
|---------|----------|----------|----------------------|
| Batching | Built-in, configurable | Manual implementation | Manual implementation |
| Back-pressure | Automatic | Automatic (demand-driven) | Manual |
| Fault tolerance | Automatic restart, ack/fail | Manual supervision | Manual |
| Kafka offset management | Via BroadwayKafka | Manual | Manual |
| Concurrency control | Declarative | Manual GenServer pools | Manual |
| Telemetry integration | Built-in | Add-on | Manual |
| Learning curve | Low (declarative) | Medium | High |

### Configuration (v1)

```elixir
# Event Collector Broadway pipeline
Broadway.start_link(EventCollector.Pipeline,
  name: EventCollector.Pipeline,
  producer: [
    module: {BroadwayKafka.Producer, [
      hosts: [kafka: 9092],
      group_id: "experimenthub-event-collector",
      topics: ["experimenthub.events.inbound"]
    ]},
    concurrency: 6  # Match Kafka partition count / 2
  ],
  processors: [
    default: [concurrency: 12]  # 2× producer concurrency
  ],
  batchers: [
    postgres: [concurrency: 4, batch_size: 500, batch_timeout: 1000]
  ]
)
```

### Alternatives Rejected
- **GenStage**: Lower-level, requires manually building batching, offset management, and fault tolerance. More code for the same result. Violates Article VII.
- **Manual Kafka consumer (brod/kafka_ex)**: Maximum control but requires implementing every feature manually. Only justified for extreme customization needs we don't have.

---

## R6: Rust NIF Safety in BEAM VM

### Decision: Use Rustler with dirty NIF schedulers for CPU-bound assignment

### Rationale
Rust NIFs via Rustler are the BEAM-endorsed approach for CPU-intensive, deterministic computations. MurmurHash3 assignment is a pure function with bounded execution time (~1μs), making it safe for NIF execution.

### Safety Analysis

| Risk | Mitigation |
|------|-----------|
| NIF crash takes down BEAM VM | Rustler uses safe Rust (no `unsafe` blocks in our code). MurmurHash3 has no panic paths. All inputs are bounded strings. |
| Long-running NIF blocks scheduler | Assignment computation is O(1) with deterministic ~1μs execution. No risk of scheduler blocking. |
| Memory leak in NIF | Rustler manages memory via Rust ownership. No manual allocation/deallocation. |
| NIF version mismatch | Rustler compiles NIF at build time with version check. Detected at application start. |

### Rustler Configuration

```rust
// Using Rustler for safe NIF bindings
#[rustler::nif]
fn assign_variant(
    user_id: String,
    experiment_id: String,
    variants: Vec<(String, u32)>, // (variant_key, weight)
) -> String {
    // Pure function: hash → bucket → variant lookup
    // No I/O, no allocation beyond return string, no panic paths
    assignment_core::assign(&user_id, &experiment_id, &variants)
}

rustler::init!("Elixir.AssignmentEngine.Native");
```

### Performance Budget
- NIF execution: ~1μs (MurmurHash3 + modulo + lookup)
- Elixir wrapper overhead: ~2-5μs (term encoding/decoding)
- Redis cache check (cache miss): ~200μs
- Total with cache hit: ~5μs (well under 5ms target)
- Total with cache miss: ~250μs (still well under 5ms target)

### Alternatives Rejected
- **Port/external process**: 100μs-1ms overhead per call due to process communication. Acceptable but unnecessary when NIF is safe.
- **Pure Elixir hash**: Elixir's :erlang.phash2 is fast but doesn't produce cross-platform reproducible MurmurHash3 values needed for the standalone Rust library / WASM SDK.
- **HTTP microservice**: Adds 1-2ms network latency per call. At 10K rps, this is 10K additional HTTP round-trips per second.

---

## R8: Redis Failure Handling & Fallback Strategy

### Decision: Cache-bypass with direct DB fallback; no data loss on Redis outage

### Rationale
Redis is used as a performance optimization cache (experiment config, feature flags, rate limiting), NOT as a source of truth. The system must degrade gracefully when Redis is unavailable.

### Failure Modes & Mitigations

| Failure Mode | Impact | Mitigation |
|---|---|---|
| Redis fully down | Assignment cache misses → direct PostgreSQL query for experiment config. Rate limiting disabled (fail-open). | Redix connection pool retries with exponential backoff. Assignment latency increases from ~5μs to ~2ms (still well under 5ms p99 target). |
| Redis high latency (>50ms) | Cache becomes slower than DB lookup | Configurable cache read timeout (default 10ms). On timeout, bypass cache and query DB directly. Log warning for monitoring. |
| Redis data loss (restart without persistence) | Cache cold → all requests hit DB until TTL repopulates | Cache-aside pattern means cold cache self-heals within 5 minutes (TTL). No action required beyond monitoring increased DB load. |
| Redis network partition | Inconsistent reads between app instances | Acceptable for cache use case. Stale data resolves within TTL (5 min). No split-brain risk since Redis is not the source of truth. |

### Rate Limiting Fallback
When Redis is unavailable, rate limiting MUST fail-open (allow all requests). This prevents a Redis outage from blocking all API traffic. A log warning is emitted for every bypassed rate limit check. Tenant-level rate limits can be enforced at the load balancer level as a secondary defense.

### Configuration
```elixir
config :experiment_hub,
  redis_cache_timeout_ms: 10,          # Max time to wait for Redis read
  redis_fallback_enabled: true,        # Enable DB fallback on Redis failure
  rate_limit_fail_open: true           # Allow requests when Redis down
```

### Alternatives Rejected
- **Redis Sentinel/Cluster for HA**: Adds operational complexity. For v1 with 5 tenants, a single Redis instance with cache-aside pattern is sufficient. HA Redis can be adopted later without code changes.
- **Local in-process cache (ETS)**: Would duplicate caching logic and create cache coherency challenges across nodes. Redis serves as the shared cache layer.

---

## R9: Kafka Consumer Offset & Delivery Strategy

### Decision: At-least-once delivery with idempotent consumers

### Rationale
At-least-once delivery provides the strongest guarantee against data loss. Combined with idempotent writes (deduplication via `idempotency_key`), this achieves effectively-once semantics without the complexity and performance overhead of Kafka's exactly-once transactions.

### Offset Management

| Strategy | Pros | Cons | Verdict |
|---|---|---|---|
| **Auto-commit (periodic)** | Simple. BroadwayKafka default. | Small window for re-delivery after crash. | **Selected** — idempotent consumers handle duplicates. |
| Manual commit after processing | Exact control over commit timing | More code, slight latency impact | Unnecessary when consumers are idempotent |
| Kafka transactions (exactly-once) | Zero duplicates | 30% throughput reduction. Complex. Requires transactional producer + consumer coordination | Overkill when deduplication handles duplicates at DB level |

### BroadwayKafka Offset Behavior
- BroadwayKafka uses `group_id`-based consumer groups with auto-committed offsets.
- Offsets are committed after each batch is successfully processed and acknowledged.
- On consumer crash, the consumer group rebalances and replays from the last committed offset.
- Duplicate messages are handled by `UNIQUE(tenant_id, idempotency_key)` constraint and `ON CONFLICT DO NOTHING`.

### Dead Letter Handling
Events that fail validation are NOT sent to a dead-letter topic in v1. Instead:
1. Invalid events return descriptive errors in the API response (207 partial success).
2. Events that pass API validation but fail downstream processing (rare: DB errors, schema evolution) are logged with full payload to structured logs for manual investigation.
3. A dead-letter topic (`experimenthub.events.dead`) is a v2 consideration for automated retry/forensics.

### Alternatives Rejected
- **Exactly-once semantics**: Kafka transactions reduce throughput by ~30% and require transactional producers. Since our consumers are idempotent (DB deduplication), the complexity isn't justified.
- **At-most-once**: Unacceptable for experimentation data. Lost events bias statistical results.

---

## R10: Excel Export Library for Elixir

### Decision: `elixlsx` (pure Elixir XLSX writer)

### Rationale
`elixlsx` is a pure Elixir library for generating `.xlsx` files (Excel 2007+ format). It has no native dependencies, integrates cleanly into the BEAM ecosystem, and supports the features needed for experiment result export (multiple sheets, styled headers, numeric formatting).

### Evaluation

| Library | Language | Native Deps | Multi-sheet | Styling | Notes |
|---|---|---|---|---|---|
| **elixlsx** | Elixir | None | Yes | Basic (bold, colors, number formats) | Pure Elixir. Active maintenance. ~50KB dependency. |
| xlsxir | Elixir | None | Read-only | N/A | Read-only — cannot write XLSX. Rejected. |
| Python openpyxl (via port) | Python | None | Yes | Rich | Cross-language call overhead. Adds Python dependency to Elixir service. |
| csv + LibreOffice conversion | Shell | LibreOffice | No | No | Brittle. Requires headless LibreOffice installation. |

### Usage Pattern
```elixir
# Generate experiment export
Elixlsx.write_to_memory("experiment_results.xlsx", %Elixlsx.Workbook{
  sheets: [
    {"Summary", [["Metric", "Control", "Treatment", "Lift", "P-Value"], ...]},
    {"Daily Results", [["Date", "Variant", "Sample Size", "Conversions", "Rate"], ...]},
    {"Statistical Detail", [["Method", "Value"], ...]}
  ]
})
```

### Dependency Addition
```elixir
# mix.exs
{:elixlsx, "~> 0.6"}
```

---

## R11: Kafka Inbound Topic Design

### Decision: Separate `experimenthub.events.inbound` pre-validation topic

### Rationale
A dedicated inbound topic (`experimenthub.events.inbound`) separates the API write path from the validation/persistence pipeline. The REST API produces to this topic asynchronously (fire-and-forget), achieving sub-10ms response latency. The Broadway consumer reads from this topic, validates, deduplicates, and writes valid events to `experimenthub.events.raw`.

This 2-topic design was not covered in R3's initial topic enumeration. R3 defined 4 topics (`events.raw`, `assignments`, `lifecycle`, `audit`). The `events.inbound` topic is a 5th topic that sits upstream of `events.raw`.

### Topic Flow
```
Client → REST API → Kafka(events.inbound) → Broadway Consumer → Validate → Kafka(events.raw) + PostgreSQL
                                                                  ↓ (invalid)
                                                            207 / 400 error response logged
```

### Topic Configuration
| Topic | Partitions | Retention | Key |
|---|---|---|---|
| `experimenthub.events.inbound` | 12 | 48 hours | `tenant_id:experiment_id` |

The 48-hour retention on the inbound topic provides a replay window for debugging validation issues.

---

## R7: WASM Bundle Size Optimization for Browser SDK

### Decision: Minimal WASM module (~15KB gzipped) with assignment logic only

### Rationale
The browser SDK needs deterministic assignment evaluation client-side for zero-latency variant resolution. Only the hash + assignment logic is compiled to WASM; event tracking uses standard fetch().

### Size Budget

| Component | Estimated Size (gzipped) |
|-----------|-------------------------|
| MurmurHash3 implementation | ~2 KB |
| Assignment logic (bucket → variant) | ~1 KB |
| wasm-bindgen glue code | ~5 KB |
| WASM runtime overhead | ~7 KB |
| **Total** | **~15 KB** |

### Optimization Techniques
- `wasm-opt -Oz` for size optimization
- `#[cfg(target_arch = "wasm32")]` to exclude NIF-specific code
- No `std` dependencies beyond what wasm-bindgen requires
- `lto = true` and `opt-level = "z"` in release profile

### SDK API (Browser)

```typescript
// Thin TypeScript wrapper around WASM module
import init, { assign_variant } from '@experimenthub/sdk-wasm';

await init(); // Load WASM module (~15KB)

const variant = assign_variant(
  "user123",
  "checkout-button-color",
  [["control", 50], ["treatment", 50]]
);
// Returns: "treatment" — deterministic, no network call
```

### Event tracking uses standard HTTP (no WASM):
```typescript
experimentHub.track("checkout_completed", { value: 1 });
// → POST /v1/events with fetch()
```

### Alternatives Rejected
- **Full SDK in WASM**: Would include event buffering, HTTP client, config fetching — ballooning to 100KB+. Violates Article VII.
- **JavaScript-only SDK**: Would need a JS MurmurHash3 implementation. Diverges from the Rust canonical implementation, risking assignment inconsistency between server and client.
- **No client-side assignment**: Forces a network round-trip for every assignment. Adds latency and creates a hard dependency on the assignment service (contradicts fail-open requirement in US2).
