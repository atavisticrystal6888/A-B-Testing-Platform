"""Daily rollup aggregation: raw events → experiment_results_daily.
Aggregates sample_size, conversions, sum_value, sum_squared_value per variant per day.

Raw events carry an ``event_name`` but no ``metric_definition_id``; at flush time
the event_name is resolved against the tenant's ``metric_definitions`` rows
(``definition->>'event_name'``). Rollups whose event_name matches no metric
definition are skipped with a warning — NULL metric_definition_id must never be
inserted because Postgres treats NULLs as distinct in the unique index
(tenant_id, experiment_id, variant_id, metric_definition_id, date), which would
break ON CONFLICT deduplication.
"""
from __future__ import annotations

import logging
import os
from collections import defaultdict
from datetime import date, datetime
from typing import Any

logger = logging.getLogger(__name__)

DEFAULT_DATABASE_URL = (
    "postgresql://experimenthub:experimenthub_dev@localhost:5432/experiment_hub_dev"
)

_METRIC_LOOKUP_SQL = """
    SELECT definition->>'event_name', id
    FROM metric_definitions
    WHERE tenant_id = %s
"""

# sample_size semantics: within a single flush, sample_size is the exact count of
# unique users seen in the buffer. Across flushes it is ADDITIVE
# (existing + EXCLUDED), which approximates unique users: a user active in more
# than one flush window (or more than one consumer instance) is counted once per
# window. Exact cross-flush uniqueness would require persistent per-user state;
# the additive approximation is monotone, cheap, and consistent with the additive
# conversions / sum_value / sum_squared_value columns.
_UPSERT_SQL = """
    INSERT INTO experiment_results_daily
        (id, tenant_id, experiment_id, variant_id, metric_definition_id,
         date, sample_size, conversions, sum_value, sum_squared_value,
         inserted_at, updated_at)
    VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, now(), now())
    ON CONFLICT (tenant_id, experiment_id, variant_id, metric_definition_id, date)
    DO UPDATE SET
        sample_size = experiment_results_daily.sample_size + EXCLUDED.sample_size,
        conversions = experiment_results_daily.conversions + EXCLUDED.conversions,
        sum_value = experiment_results_daily.sum_value + EXCLUDED.sum_value,
        sum_squared_value = experiment_results_daily.sum_squared_value
            + EXCLUDED.sum_squared_value,
        updated_at = now()
"""


class DailyRollupAggregator:
    """Aggregates raw events into daily rollup records."""

    def __init__(self, db_url: str | None = None) -> None:
        self.db_url = db_url or os.getenv("DATABASE_URL", DEFAULT_DATABASE_URL)
        # In-memory buffer for batch processing, keyed by
        # tenant:experiment:variant:event_name:date.
        self._buffer: defaultdict[str, dict[str, Any]] = defaultdict(
            lambda: {
                "sample_size": 0,
                "conversions": 0,
                "sum_value": 0.0,
                "sum_squared_value": 0.0,
                "users": set(),
            }
        )

    def aggregate_event(self, event: dict[str, Any]) -> None:
        """Aggregate a single event into the buffer."""
        tenant_id = event.get("tenant_id", "")
        experiment_id = event.get("experiment_id", "")
        variant_id = event.get("variant_id", "")
        user_id = event.get("user_id", "")
        event_type = event.get("event_type", "")
        event_name = event.get("event_name", "")
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

        key = (
            f"{tenant_id}:{experiment_id}:{variant_id}:{event_name}:{event_date.isoformat()}"
        )

        entry = self._buffer[key]
        entry["tenant_id"] = tenant_id
        entry["experiment_id"] = experiment_id
        entry["variant_id"] = variant_id
        entry["event_name"] = event_name
        entry["date"] = event_date

        # Track unique users for sample size (exact within this buffer only;
        # see the sample_size semantics note above _UPSERT_SQL).
        entry["users"].add(user_id)
        entry["sample_size"] = len(entry["users"])

        if event_type == "conversion":
            entry["conversions"] += 1

        entry["sum_value"] += value
        entry["sum_squared_value"] += value * value

    def flush(self) -> None:
        """Flush buffered aggregations to database.

        Resolves event_name → metric_definition_id per tenant (one lookup query
        per tenant per flush, cached for the duration of the flush). Rollups
        with no matching metric definition are dropped with a warning.
        """
        if not self._buffer:
            return

        try:
            import psycopg2

            conn = psycopg2.connect(self.db_url)
            try:
                cursor = conn.cursor()
                metric_ids = self._resolve_metric_ids(cursor)

                written = 0
                skipped = 0
                for entry in self._buffer.values():
                    metric_definition_id = metric_ids.get(
                        (entry["tenant_id"], entry["event_name"])
                    )
                    if metric_definition_id is None:
                        skipped += 1
                        logger.warning(
                            "Skipping rollup for tenant %s: event_name %r matches "
                            "no metric definition",
                            entry["tenant_id"],
                            entry["event_name"],
                        )
                        continue

                    cursor.execute(
                        _UPSERT_SQL,
                        (
                            entry["tenant_id"],
                            entry["experiment_id"],
                            entry["variant_id"],
                            metric_definition_id,
                            entry["date"],
                            entry["sample_size"],
                            entry["conversions"],
                            entry["sum_value"],
                            entry["sum_squared_value"],
                        ),
                    )
                    written += 1

                conn.commit()
                cursor.close()
            finally:
                conn.close()

            logger.info(
                "Flushed %d aggregation records (%d skipped, no metric definition)",
                written,
                skipped,
            )
            self._buffer.clear()

        except ImportError:
            logger.warning("psycopg2 not installed, cannot flush to database")
        except Exception:
            logger.exception("Error flushing aggregations")

    def _resolve_metric_ids(self, cursor: Any) -> dict[tuple[str, str], str]:
        """Build a (tenant_id, event_name) → metric_definition_id map.

        One query per distinct tenant in the buffer; the result is the per-flush
        cache used by flush().
        """
        mapping: dict[tuple[str, str], str] = {}
        tenant_ids = sorted({entry["tenant_id"] for entry in self._buffer.values()})
        for tenant_id in tenant_ids:
            cursor.execute(_METRIC_LOOKUP_SQL, (tenant_id,))
            for event_name, metric_definition_id in cursor.fetchall():
                if event_name:
                    mapping[(tenant_id, event_name)] = metric_definition_id
        return mapping

    def get_buffer_size(self) -> int:
        return len(self._buffer)
