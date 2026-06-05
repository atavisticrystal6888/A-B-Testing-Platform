//! WASM build target for assignment_core (FR-210)
//!
//! Enables client-side assignment computation for edge/browser use cases.
//! Build with: `wasm-pack build --target web`

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

#[cfg(target_arch = "wasm32")]
use crate::hash::murmur3_32;

/// Assign a user to a variant using deterministic hashing (WASM export).
///
/// # Arguments
/// * `experiment_id` - Unique experiment identifier
/// * `user_id` - Unique user identifier
/// * `weights` - Comma-separated variant weights (e.g., "50,50" or "33,33,34")
///
/// # Returns
/// Zero-based variant index
#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
pub fn assign_variant(experiment_id: &str, user_id: &str, weights: &str) -> i32 {
    let weight_vec: Vec<u32> = weights
        .split(',')
        .filter_map(|w| w.trim().parse::<u32>().ok())
        .collect();

    if weight_vec.is_empty() {
        return -1;
    }

    let seed = format!("{}-{}", experiment_id, user_id);
    let hash = murmur3_32(seed.as_bytes(), 0);
    let total_weight: u32 = weight_vec.iter().sum();

    if total_weight == 0 {
        return -1;
    }

    let bucket = hash % total_weight;
    let mut cumulative: u32 = 0;

    for (idx, weight) in weight_vec.iter().enumerate() {
        cumulative += weight;
        if bucket < cumulative {
            return idx as i32;
        }
    }

    (weight_vec.len() - 1) as i32
}

/// Compute a deterministic hash for a user-experiment pair (WASM export).
#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]
pub fn compute_hash(experiment_id: &str, user_id: &str) -> u32 {
    let seed = format!("{}-{}", experiment_id, user_id);
    murmur3_32(seed.as_bytes(), 0)
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_wasm_module_compiles() {
        // Verify the module compiles; actual WASM tests require wasm-pack
        assert!(true);
    }
}
