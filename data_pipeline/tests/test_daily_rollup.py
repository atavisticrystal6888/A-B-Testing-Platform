"""Unit tests for daily event rollup aggregation."""

from datetime import date

from src.aggregators.daily_rollup import DailyRollupAggregator


def test_aggregate_event_rolls_up_counts_unique_users_and_values():
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")

    base_event = {
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-a",
        "event_type": "conversion",
        "timestamp": "2026-07-14T12:30:00Z",
    }

    aggregator.aggregate_event({**base_event, "user_id": "user-1", "value": "2.5"})
    aggregator.aggregate_event({**base_event, "user_id": "user-1", "value": 1})
    aggregator.aggregate_event({**base_event, "user_id": "user-2", "value": 3})

    assert aggregator.get_buffer_size() == 1

    [entry] = list(aggregator._buffer.values())
    assert entry["tenant_id"] == "tenant-1"
    assert entry["experiment_id"] == "experiment-1"
    assert entry["variant_id"] == "variant-a"
    assert entry["date"] == date(2026, 7, 14)
    assert entry["sample_size"] == 2
    assert entry["conversions"] == 3
    assert entry["sum_value"] == 6.5
    assert entry["sum_squared_value"] == 16.25


def test_aggregate_event_skips_bot_and_post_conclusion_events():
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")

    event = {
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-a",
        "user_id": "user-1",
        "event_type": "conversion",
        "timestamp": "2026-07-14T12:30:00Z",
    }

    aggregator.aggregate_event({**event, "is_bot": True})
    aggregator.aggregate_event({**event, "is_post_conclusion": True})

    assert aggregator.get_buffer_size() == 0


def test_aggregate_event_groups_by_variant_and_day():
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")

    aggregator.aggregate_event({
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-a",
        "user_id": "user-1",
        "event_type": "view",
        "timestamp": "2026-07-14T10:00:00Z",
    })
    aggregator.aggregate_event({
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-b",
        "user_id": "user-2",
        "event_type": "view",
        "timestamp": "2026-07-14T10:00:00Z",
    })
    aggregator.aggregate_event({
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-a",
        "user_id": "user-3",
        "event_type": "view",
        "timestamp": "2026-07-15T10:00:00Z",
    })

    assert aggregator.get_buffer_size() == 3
