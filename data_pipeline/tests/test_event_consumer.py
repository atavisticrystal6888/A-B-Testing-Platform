"""Unit tests for the event consumer's flush cadence (no real Kafka or DB)."""

import json

from src.consumers.event_consumer import EventConsumer


class RecordingAggregator:
    """Stands in for DailyRollupAggregator; records calls, never touches a DB."""

    def __init__(self):
        self.events = []
        self.flush_count = 0
        self._buffered = 0

    def aggregate_event(self, event):
        self.events.append(event)
        self._buffered += 1

    def flush(self):
        self.flush_count += 1
        self._buffered = 0

    def get_buffer_size(self):
        return self._buffered


class FakeMessage:
    def __init__(self, raw: bytes):
        self._raw = raw

    def value(self):
        return self._raw

    def error(self):
        return None

    def key(self):
        return b"key"


class FakeKafkaConsumer:
    """Yields queued messages, then stops the owning EventConsumer."""

    def __init__(self, messages):
        self._messages = list(messages)
        self.owner = None
        self.subscribed_topics = None
        self.closed = False

    def subscribe(self, topics):
        self.subscribed_topics = topics

    def poll(self, timeout=1.0):
        if self._messages:
            return self._messages.pop(0)
        if self.owner is not None:
            self.owner._running = False
        return None

    def close(self):
        self.closed = True


def _event(user_id="user-1"):
    return {
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "variant_id": "variant-a",
        "user_id": user_id,
        "event_type": "conversion",
        "event_name": "checkout_completed",
        "value": 1,
        "timestamp": "2026-07-14T12:30:00Z",
    }


def test_consumer_owns_one_aggregator_and_flushes_every_n_events():
    aggregator = RecordingAggregator()
    consumer = EventConsumer(
        aggregator=aggregator, flush_max_events=3, flush_interval_seconds=3600
    )

    for i in range(7):
        consumer.process_event(_event(user_id=f"user-{i}"))

    # Flushed at events 3 and 6; the seventh event is still buffered.
    assert aggregator.flush_count == 2
    assert len(aggregator.events) == 7
    assert consumer.aggregator is aggregator


def test_stop_performs_final_flush_and_closes_kafka_consumer():
    aggregator = RecordingAggregator()
    fake_kafka = FakeKafkaConsumer([])
    consumer = EventConsumer(
        aggregator=aggregator,
        consumer=fake_kafka,
        flush_max_events=500,
        flush_interval_seconds=3600,
    )

    consumer.process_event(_event())
    assert aggregator.flush_count == 0

    consumer.stop()

    assert aggregator.flush_count == 1
    assert fake_kafka.closed is True


def test_poll_loop_flushes_on_time_interval_and_survives_bad_json():
    aggregator = RecordingAggregator()
    messages = [
        FakeMessage(json.dumps(_event(user_id="user-1")).encode("utf-8")),
        FakeMessage(b"not valid json"),
        FakeMessage(json.dumps(_event(user_id="user-2")).encode("utf-8")),
    ]
    fake_kafka = FakeKafkaConsumer(messages)
    consumer = EventConsumer(
        aggregator=aggregator,
        consumer=fake_kafka,
        flush_max_events=1000,  # count threshold never reached
        flush_interval_seconds=0.0,  # every loop iteration is "interval elapsed"
    )
    fake_kafka.owner = consumer

    consumer.start()

    assert fake_kafka.subscribed_topics == ["experimenthub.events.raw"]
    # Bad JSON is skipped without killing the loop.
    assert len(aggregator.events) == 2
    # Interval flushes fired during the loop, plus the final flush in stop().
    assert aggregator.flush_count >= 2
    assert aggregator.get_buffer_size() == 0
    assert fake_kafka.closed is True


def test_flush_thresholds_are_env_configurable(monkeypatch):
    monkeypatch.setenv("ROLLUP_FLUSH_MAX_EVENTS", "42")
    monkeypatch.setenv("ROLLUP_FLUSH_INTERVAL_SECONDS", "2.5")

    consumer = EventConsumer(aggregator=RecordingAggregator())

    assert consumer.flush_max_events == 42
    assert consumer.flush_interval_seconds == 2.5


def test_flush_threshold_defaults():
    consumer = EventConsumer(aggregator=RecordingAggregator())

    assert consumer.flush_max_events == 500
    assert consumer.flush_interval_seconds == 10.0
