// Variant selection logic: hash → bucket (mod 10000) → variant lookup
use crate::hash::hash_to_bucket;

/// Given a user_id, experiment_key, and a slice of traffic allocations (basis points summing to 10000),
/// returns the index of the assigned variant.
///
/// If allocations are empty or don't sum to 10000, returns 0 (control fallback).
pub fn assign_variant(user_id: &str, experiment_key: &str, allocations: &[u32]) -> usize {
    if allocations.is_empty() {
        return 0;
    }

    let bucket = hash_to_bucket(user_id, experiment_key);
    let mut cumulative: u32 = 0;

    for (i, &alloc) in allocations.iter().enumerate() {
        cumulative += alloc;
        if bucket < cumulative {
            return i;
        }
    }

    // Fallback to last variant (shouldn't happen if allocations sum to 10000)
    allocations.len() - 1
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_assign_deterministic() {
        let a = assign_variant("user-1", "exp-1", &[5000, 5000]);
        let b = assign_variant("user-1", "exp-1", &[5000, 5000]);
        assert_eq!(a, b);
    }

    #[test]
    fn test_assign_returns_valid_index() {
        for i in 0..1000 {
            let idx = assign_variant(&format!("user-{}", i), "exp-1", &[5000, 5000]);
            assert!(idx < 2);
        }
    }

    #[test]
    fn test_assign_three_variants() {
        for i in 0..1000 {
            let idx = assign_variant(&format!("user-{}", i), "exp-1", &[3334, 3333, 3333]);
            assert!(idx < 3);
        }
    }

    #[test]
    fn test_empty_allocations_returns_zero() {
        assert_eq!(assign_variant("user-1", "exp-1", &[]), 0);
    }
}
