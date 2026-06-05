pub mod hash;
pub mod assignment;

pub use assignment::assign_variant;

// Rustler NIF bindings for Elixir interop
#[cfg(not(target_arch = "wasm32"))]
mod nif {
    use rustler::{Env, Term, NifResult};

    rustler::init!("Elixir.AssignmentEngine.Native");

    #[rustler::nif]
    fn hash_to_bucket(user_id: &str, experiment_key: &str) -> u32 {
        crate::hash::hash_to_bucket(user_id, experiment_key)
    }

    #[rustler::nif]
    fn assign_variant(user_id: &str, experiment_key: &str, allocations: Vec<u32>) -> usize {
        crate::assignment::assign_variant(user_id, experiment_key, &allocations)
    }
}
