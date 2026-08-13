use criterion::{black_box, criterion_group, criterion_main, Criterion};

use assignment_core::assignment::assign_variant;
use assignment_core::hash::hash_to_bucket;

fn bench_hash_to_bucket(c: &mut Criterion) {
    c.bench_function("hash_to_bucket", |b| {
        b.iter(|| hash_to_bucket(black_box("user-4f2a9c31"), black_box("checkout-copy-demo")))
    });
}

fn bench_assign_variant_two_way(c: &mut Criterion) {
    let allocations = [50, 50];

    c.bench_function("assign_variant/2_variants", |b| {
        b.iter(|| {
            assign_variant(
                black_box("user-4f2a9c31"),
                black_box("checkout-copy-demo"),
                black_box(&allocations),
            )
        })
    });
}

fn bench_assign_variant_multi_way(c: &mut Criterion) {
    let allocations = [25, 25, 25, 25];

    c.bench_function("assign_variant/4_variants", |b| {
        b.iter(|| {
            assign_variant(
                black_box("user-4f2a9c31"),
                black_box("pricing-layout-demo"),
                black_box(&allocations),
            )
        })
    });
}

criterion_group!(
    benches,
    bench_hash_to_bucket,
    bench_assign_variant_two_way,
    bench_assign_variant_multi_way
);
criterion_main!(benches);
