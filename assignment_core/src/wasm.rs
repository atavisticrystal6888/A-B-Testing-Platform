//! Intentionally empty. The previous WASM export path was never compiled into
//! the crate (no `mod wasm;` exists) and its algorithm diverged from the
//! canonical bucketing in `hash.rs` on three axes (murmur3_32 instead of
//! murmur3_x64_128, `"-"` separator instead of `":"`, and modulo total_weight
//! instead of 10_000) — wiring it up would have broken client/server
//! assignment parity for effectively every user.
//!
//! A future browser-side implementation must reuse `hash::hash_to_bucket` and
//! stay pinned by the golden vectors in `tests/assignment_test.rs`.
