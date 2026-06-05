"""Daily rollup aggregation: raw events → experiment_results_daily.
Aggregates sample_size, conversions, sum_value, sum_squared_value per variant per day.
"""
from __future__ import annotations

import logging
import os
from collections import defaultdict
from datetime import date, datetime
from typing import Any

logger = logging.getLogger(__name__)


class DailyRollupAggregator:
    """Aggregates raw events into daily rollup records."""

    def __init__(self, db_url: str | None = None):
        self.db_url = db_url or os.getenv(
            "DATABASE_URL",
            "postgresql://postgres:postgres@localhost:5432/experiment_hub_dev",
        )
        # In-memory buffer for batch processing
        self._buffer: dict[str, dict[str, Any]] = defaultdict(
            lambda: {
                "sample_size": 0,
                "conversions": 0,
                "sum_value": 0.0,
                "sum_squared_value": 0.0,
                "users": set(),
            }
        )

    def aggregate_event(self, event: dict[str, Any]):
        """Aggregate a single event into the buffer."""
        tenant_id = event.get("tenant_id", "")
        experiment_id = event.get("experiment_id", "")
        variant_id = event.get("variant_id", "")
        user_id = event.get("user_id", "")
        event_type = event.get("event_type", "")
        value = float(event.get("value", 0) or 0)

        # Skip bot events
        if event.get("is_bot", False):
            return

        # Skip post-conclusion events
        if event.get("is_post_conclusion", False):
            return

        timestamp = event.get("timestamp", "")
        try:
            if isinstance(timestamp, str):
                event_date = datetime.fromisoformat(timestamp.replace("Z", "+00:00")).date()
            else:
                event_date = date.today()
        except (ValueError, AttributeError):
            event_date = date.today()

        key = f"{tenant_id}:{experiment_id}:{variant_id}:{event_date.isoformat()}"

        entry = self._buffer[key]
        entry["tenant_id"] = tenant_id
        entry["experiment_id"] = experiment_id
        entry["variant_id"] = variant_id
        entry["date"] = event_date

        # Track unique users for sample size
        entry["users"].add(user_id)
        entry["sample_size"] = len(entry["users"])

        if event_type == "conversion":
            entry["conversions"] += 1

        entry["sum_value"] += value
        entry["sum_squared_value"] += value * value

    def flush(self):
        """Flush buffered aggregations to database."""
        if not self._buffer:
            return

        try:
            import psycopg2

            conn = psycopg2.connect(self.db_url)
            cursor = conn.cursor()

            for _key, entry in self._buffer.items():
                cursor.execute(
                    """
                    INSERT INTO experiment_results_daily
                        (id, tenant_id, experiment_id, variant_id, metric_definition_id,
                         date, sample_size, conversions, sum_value, sum_squared_value,
                         inserted_at, updated_at)
                    VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), now())
                    ON CONFLICT (tenant_id, experiment_id, variant_id, metric_definition_id, date)
                    DO UPDATE SET
                        sample_size = EXCLUDED.sample_size,
                        conversions = experiment_results_daily.conversions + EXCLUDED.conversions,
                        sum_value = experiment_results_daily.sum_value + EXCLUDED.sum_value,
                        sum_squared_value = experiment_results_daily.sum_squared_value + EXCLUDED.sum_squared_value,
                        updated_at = now()
                    """,
                    (
                        entry["tenant_id"],
                        entry["experiment_id"],
                        entry["variant_id"],
                        None,  # metric_definition_id - to be resolved
                        entry["date"],
                        entry["sample_size"],
                        entry["conversions"],
                        entry["sum_value"],
                        entry["sum_squared_value"],
                    ),
                )

            conn.commit()
            cursor.close()
            conn.close()

            logger.info(f"Flushed {len(self._buffer)} aggregation records")
            self._buffer.clear()

        except ImportError:
            logger.warning("psycopg2 not installed, cannot flush to database")
        except Exception:
            logger.exception("Error flushing aggregations")

    def get_buffer_size(self) -> int:
        return len(self._buffer)
