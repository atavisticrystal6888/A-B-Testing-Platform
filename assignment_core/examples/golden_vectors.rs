//! Prints golden hash/bucket vectors used to verify cross-implementation
//! parity between this crate and the pure-Elixir fallback in
//! apps/assignment_engine (see native_test.exs).
//!
//! Run: cargo run --example golden_vectors

fn main() {
    let cases = [
        ("exp-1", "user-1"),
        ("exp-1", "user-2"),
        ("checkout-cta", "manual-e2e-user-001"),
        ("exp-unicode", "üser-ñ"),
        ("exp-long", "a-rather-long-user-identifier-0123456789"),
        ("e", "u"),
        ("exp-1", ""),
        ("", "user-1"),
    ];

    for (exp, user) in cases {
        let input = format!("{}:{}", exp, user);
        let hash = assignment_core::hash::murmur3_128(&input, 0);
        let bucket = assignment_core::hash::hash_to_bucket(user, exp);
        println!("{}\t{}\t{}\t{}", exp, user, hash, bucket);
    }
}
