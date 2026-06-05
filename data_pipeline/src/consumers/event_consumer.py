"""Kafka consumer for experimenthub.events.raw topic.
Consumes raw events and feeds them to the daily rollup aggregator.
"""
from __future__ import annotations

import json
import logging
import os
import signal
import sys
from typing import Any

logger = logging.getLogger(__name__)


class EventConsumer:
    """Kafka consumer for raw experiment events."""

    def __init__(
        self,
        bootstrap_servers: str | None = None,
        group_id: str = "experimenthub-data-pipeline",
        topic: str = "experimenthub.events.raw",
    ):
        self.bootstrap_servers = bootstrap_servers or os.getenv(
            "KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"
        )
        self.group_id = group_id
        self.topic = topic
        self._running = False
        self._consumer = None

    def start(self):
        """Start consuming events."""
        try:
            from confluent_kafka import Consumer, KafkaError

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

            logger.info(f"Started consuming from {self.topic}")

            while self._running:
                msg = self._consumer.poll(timeout=1.0)
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

    def stop(self):
        """Stop the consumer."""
        self._running = False
        if self._consumer:
            self._consumer.close()
            self._consumer = None

    def process_event(self, event: dict[str, Any]):
        """Process a single event. Override in subclass or call aggregator."""
        from src.aggregators.daily_rollup import DailyRollupAggregator

        aggregator = DailyRollupAggregator()
        aggregator.aggregate_event(event)


def main():
    """Entry point for the event consumer."""
    logging.basicConfig(level=logging.INFO)
    consumer = EventConsumer()

    def signal_handler(sig, frame):
        logger.info("Shutting down consumer...")
        consumer.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    consumer.start()


if __name__ == "__main__":
    main()
