"""Unit tests for daily event rollup aggregation."""

import logging
from datetime import date

from src.aggregators.daily_rollup import DailyRollupAggregator


class FakeCursor:
    """Records executed SQL; serves metric_definitions lookups from a fixture."""

    def __init__(self, metric_rows_by_tenant):
        # tenant_id -> list of (event_name, metric_definition_id) rows
        self._metric_rows_by_tenant = metric_rows_by_tenant
        self._pending_rows = []
        self.executed = []
        self.metric_lookup_count = 0
        self.closed = False

    def execute(self, sql, params=None):
        self.executed.append((sql, params))
        if "FROM metric_definitions" in sql:
            self.metric_lookup_count += 1
            self._pending_rows = list(self._metric_rows_by_tenant.get(params[0], []))

    def fetchall(self):
        rows, self._pending_rows = self._pending_rows, []
        return rows

    def close(self):
        self.closed = True


class FakeConnection:
    def __init__(self, cursor):
        self._cursor = cursor
        self.commit_count = 0
        self.closed = False

    def cursor(self):
        return self._cursor

    def commit(self):
        self.commit_count += 1

    def close(self):
        self.closed = True


def _patch_db(monkeypatch, metric_rows_by_tenant):
    cursor = FakeCursor(metric_rows_by_tenant)
    conn = FakeConnection(cursor)
    monkeypatch.setattr("psycopg2.connect", lambda _url: conn)
    return cursor, conn


def _inserts(cursor):
    return [
        (sql, params)
        for sql, params in cursor.executed
        if "INSERT INTO experiment_results_daily" in sql
    ]


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


def _make_event(**overrides):
    event = {
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-a",
        "user_id": "user-1",
        "event_type": "conversion",
        "event_name": "checkout_completed",
        "value": 2.0,
        "timestamp": "2026-07-14T12:30:00Z",
    }
    event.update(overrides)
    return event


def test_flush_resolves_event_name_to_metric_definition_id(monkeypatch):
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")
    cursor, conn = _patch_db(
        monkeypatch,
        {
            "tenant-1": [
                ("checkout_completed", "md-checkout"),
                ("order_completed", "md-order"),
            ]
        },
    )

    aggregator.aggregate_event(_make_event())
    aggregator.aggregate_event(
        _make_event(event_name="order_completed", event_type="revenue", value=10.0)
    )

    aggregator.flush()

    inserts = _inserts(cursor)
    assert len(inserts) == 2
    metric_ids = {params[3] for _sql, params in inserts}
    assert metric_ids == {"md-checkout", "md-order"}
    # Metric mapping is fetched once per tenant per flush (cached), not per row.
    assert cursor.metric_lookup_count == 1
    assert conn.commit_count == 1
    assert conn.closed is True
    assert aggregator.get_buffer_size() == 0


def test_flush_skips_unmapped_event_names_without_inserting_null(monkeypatch, caplog):
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")
    cursor, _conn = _patch_db(
        monkeypatch, {"tenant-1": [("checkout_completed", "md-checkout")]}
    )

    aggregator.aggregate_event(_make_event(event_name="unknown_event"))

    with caplog.at_level(logging.WARNING, logger="src.aggregators.daily_rollup"):
        aggregator.flush()

    assert _inserts(cursor) == []
    assert any(
        "unknown_event" in record.message and "no metric definition" in record.message
        for record in caplog.records
    )
    # Skipped rollups are dropped, never retried with a NULL metric_definition_id.
    assert aggregator.get_buffer_size() == 0


def test_flush_sample_size_is_per_flush_unique_users_and_additive_across_flushes(
    monkeypatch,
):
    """Pins the chosen semantics: sample_size counts unique users exactly within
    one flush, and the upsert ADDS it to the stored row so separate flushes
    accumulate (an approximation of unique users across flush windows)."""
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")
    cursor, _conn = _patch_db(
        monkeypatch, {"tenant-1": [("checkout_completed", "md-checkout")]}
    )

    # First flush: two distinct users, one of them twice -> sample_size 2.
    aggregator.aggregate_event(_make_event(user_id="user-1"))
    aggregator.aggregate_event(_make_event(user_id="user-1"))
    aggregator.aggregate_event(_make_event(user_id="user-2"))
    aggregator.flush()

    # Second flush: user-1 again -> sample_size 1 for this window.
    aggregator.aggregate_event(_make_event(user_id="user-1"))
    aggregator.flush()

    inserts = _inserts(cursor)
    assert len(inserts) == 2
    assert inserts[0][1][5] == 2  # sample_size, first flush
    assert inserts[1][1][5] == 1  # sample_size, second flush

    for sql, _params in inserts:
        assert (
            "sample_size = experiment_results_daily.sample_size + EXCLUDED.sample_size"
            in sql
        )
        assert (
            "conversions = experiment_results_daily.conversions + EXCLUDED.conversions"
            in sql
        )


def test_flush_keeps_buffer_on_database_error(monkeypatch):
    aggregator = DailyRollupAggregator(db_url="postgresql://example/test")

    def _boom(_url):
        raise RuntimeError("connection refused")

    monkeypatch.setattr("psycopg2.connect", _boom)

    aggregator.aggregate_event(_make_event())
    aggregator.flush()

    assert aggregator.get_buffer_size() == 1


def test_default_database_url_matches_docker_compose(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    aggregator = DailyRollupAggregator()
    assert (
        aggregator.db_url
        == "postgresql://experimenthub:experimenthub_dev@localhost:5432/experiment_hub_dev"
    )
