"""Kafka consumer for experimenthub.events.raw topic.
Consumes raw events and feeds them to the daily rollup aggregator.

The consumer owns a single DailyRollupAggregator (injectable for tests) and
flushes it every ``flush_max_events`` events (default 500, env
ROLLUP_FLUSH_MAX_EVENTS) or every ``flush_interval_seconds`` seconds (default
10, env ROLLUP_FLUSH_INTERVAL_SECONDS), whichever comes first, plus a final
flush on stop().
"""
from __future__ import annotations

import json
import logging
import os
import signal
import sys
import time
from typing import Any

from src.aggregators.daily_rollup import DailyRollupAggregator

logger = logging.getLogger(__name__)

DEFAULT_FLUSH_MAX_EVENTS = 500
DEFAULT_FLUSH_INTERVAL_SECONDS = 10.0


class EventConsumer:
    """Kafka consumer for raw experiment events."""

    def __init__(
        self,
        bootstrap_servers: str | None = None,
        group_id: str = "experimenthub-data-pipeline",
        topic: str = "experimenthub.events.raw",
        aggregator: DailyRollupAggregator | None = None,
        consumer: Any = None,
        flush_max_events: int | None = None,
        flush_interval_seconds: float | None = None,
    ) -> None:
        self.bootstrap_servers = bootstrap_servers or os.getenv(
            "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"
        )
        self.group_id = group_id
        self.topic = topic
        self.aggregator = aggregator if aggregator is not None else DailyRollupAggregator()
        self.flush_max_events = (
            flush_max_events
            if flush_max_events is not None
            else int(os.getenv("ROLLUP_FLUSH_MAX_EVENTS", str(DEFAULT_FLUSH_MAX_EVENTS)))
        )
        self.flush_interval_seconds = (
            flush_interval_seconds
            if flush_interval_seconds is not None
            else float(
                os.getenv(
                    "ROLLUP_FLUSH_INTERVAL_SECONDS", str(DEFAULT_FLUSH_INTERVAL_SECONDS)
                )
            )
        )
        self._running = False
        self._consumer: Any = consumer
        self._events_since_flush = 0
        self._last_flush = time.monotonic()

    def start(self) -> None:
        """Start consuming events."""
        try:
            from confluent_kafka import Consumer, KafkaError

            if self._consumer is None:
                self._consumer = Consumer(
                    {
                        "bootstrap.servers": self.bootstrap_servers,
                        "group.id": self.group_id,
                        "auto.offset.reset": "earliest",
                        "enable.auto.commit": True,
                        "auto.commit.interval.ms": 5000,
                    }
                )
            self._consumer.subscribe([self.topic])
            self._running = True
            self._last_flush = time.monotonic()

            logger.info(f"Started consuming from {self.topic}")

            while self._running:
                msg = self._consumer.poll(timeout=1.0)
                self._flush_if_interval_elapsed()
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        continue
                    logger.error(f"Consumer error: {msg.error()}")
                    continue

                try:
                    event = json.loads(msg.value().decode("utf-8"))
                    self.process_event(event)
                except json.JSONDecodeError:
                    logger.warning(f"Invalid JSON in message: {msg.key()}")
                except Exception:
                    logger.exception("Error processing event")

        except ImportError:
            logger.warning("confluent-kafka not installed, consumer not started")
        finally:
            self.stop()

    def stop(self) -> None:
        """Stop the consumer and flush any buffered aggregations."""
        self._running = False
        if self._consumer:
            self._consumer.close()
            self._consumer = None
        self._flush()

    def process_event(self, event: dict[str, Any]) -> None:
        """Aggregate a single event and flush when the batch size is reached."""
        self.aggregator.aggregate_event(event)
        self._events_since_flush += 1
        if self._events_since_flush >= self.flush_max_events:
            self._flush()

    def _flush_if_interval_elapsed(self) -> None:
        """Flush on the poll loop's clock when the flush interval has elapsed."""
        if time.monotonic() - self._last_flush < self.flush_interval_seconds:
            return
        if self._events_since_flush > 0 or self.aggregator.get_buffer_size() > 0:
            self._flush()
        else:
            self._last_flush = time.monotonic()

    def _flush(self) -> None:
        self.aggregator.flush()
        self._events_since_flush = 0
        self._last_flush = time.monotonic()


def main() -> None:
    """Entry point for the event consumer."""
    logging.basicConfig(level=logging.INFO)
    consumer = EventConsumer()

    def signal_handler(sig: int, frame: Any) -> None:
        logger.info("Shutting down consumer...")
        consumer.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    consumer.start()


if __name__ == "__main__":
    main()
