// MurmurHash3 128-bit hashing for deterministic variant assignment
use std::io::Cursor;

/// Compute MurmurHash3 128-bit hash and return the full value.
pub fn murmur3_128(key: &str, seed: u32) -> u128 {
    let mut reader = Cursor::new(key.as_bytes());
    murmur3::murmur3_x64_128(&mut reader, seed).unwrap_or(0)
}

/// Hash a user_id + experiment_key into a bucket in [0, 10000).
pub fn hash_to_bucket(user_id: &str, experiment_key: &str) -> u32 {
    let input = format!("{}:{}", experiment_key, user_id);
    let hash = murmur3_128(&input, 0);
    (hash % 10_000) as u32
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deterministic() {
        let a = hash_to_bucket("user-1", "exp-1");
        let b = hash_to_bucket("user-1", "exp-1");
        assert_eq!(a, b);
    }

    #[test]
    fn test_bucket_range() {
        for i in 0..1000 {
            let bucket = hash_to_bucket(&format!("user-{}", i), "exp-1");
            assert!(bucket < 10_000, "Bucket {} out of range", bucket);
        }
    }
}
