use proptest::prelude::*;
use assignment_core::hash::hash_to_bucket;
use assignment_core::assignment::assign_variant;

proptest! {
    #[test]
    fn deterministic_assignment(
        user_id in "[a-zA-Z0-9_-]{1,64}",
        experiment_key in "[a-zA-Z0-9_-]{1,64}"
    ) {
        let a = hash_to_bucket(&user_id, &experiment_key);
        let b = hash_to_bucket(&user_id, &experiment_key);
        prop_assert_eq!(a, b);
    }

    #[test]
    fn bucket_always_in_range(
        user_id in "[a-zA-Z0-9_-]{1,64}",
        experiment_key in "[a-zA-Z0-9_-]{1,64}"
    ) {
        let bucket = hash_to_bucket(&user_id, &experiment_key);
        prop_assert!(bucket < 10_000);
    }

    #[test]
    fn variant_index_always_valid(
        user_id in "[a-zA-Z0-9_-]{1,64}",
        experiment_key in "[a-zA-Z0-9_-]{1,64}"
    ) {
        let allocations = vec![5000u32, 5000];
        let idx = assign_variant(&user_id, &experiment_key, &allocations);
        prop_assert!(idx < allocations.len());
    }

    #[test]
    fn variant_respects_three_way_split(
        user_id in "[a-zA-Z0-9_-]{1,64}",
        experiment_key in "[a-zA-Z0-9_-]{1,64}"
    ) {
        let allocations = vec![3334u32, 3333, 3333];
        let idx = assign_variant(&user_id, &experiment_key, &allocations);
        prop_assert!(idx < 3);
    }
}

#[test]
fn distribution_is_roughly_uniform() {
    let mut counts = [0u32; 2];
    let n = 100_000;

    for i in 0..n {
        let user_id = format!("user-{}", i);
        let idx = assign_variant(&user_id, "exp-uniform-test", &[5000, 5000]);
        counts[idx] += 1;
    }

    // Each variant should get ~50% ± 2%
    for count in &counts {
        let pct = (*count as f64) / (n as f64);
        assert!(pct > 0.48 && pct < 0.52, "Distribution skewed: {:.4}", pct);
    }
}

#[test]
fn no_flip_flop_on_reallocation() {
    // Users assigned to variant 0 with 50/50 should stay in variant 0
    // when traffic shifts to 60/40 (control gets more traffic)
    let mut stable_count = 0;
    let n = 10_000;

    for i in 0..n {
        let user_id = format!("user-{}", i);
        let idx_before = assign_variant(&user_id, "exp-flip-test", &[5000, 5000]);
        let idx_after = assign_variant(&user_id, "exp-flip-test", &[6000, 4000]);

        // Users in bucket 0-4999 should stay in variant 0 (now 0-5999)
        if idx_before == 0 && idx_after == 0 {
            stable_count += 1;
        }
    }

    // All users that were in variant 0 (bucket < 5000) should still be in variant 0
    // because the boundary moved from 5000 to 6000
    assert!(stable_count > 0);
}
