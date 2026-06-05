"""Event filtering and data cleaning: bot filtering, validation."""
from __future__ import annotations

from typing import Any

BOT_USER_AGENTS = frozenset([
    "googlebot", "bingbot", "slurp", "duckduckbot", "baiduspider",
    "yandexbot", "facebot", "ia_archiver", "bot", "crawler", "spider",
])


def is_bot_event(event: dict[str, Any]) -> bool:
    """Check if an event is from a bot."""
    return bool(event.get("is_bot", False))


def is_valid_event(event: dict[str, Any]) -> bool:
    """Basic event validity check."""
    required = ["tenant_id", "experiment_id", "user_id", "event_type", "event_name"]
    return all(event.get(field) for field in required)


def filter_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Filter out bot events and invalid events."""
    return [
        event
        for event in events
        if is_valid_event(event) and not is_bot_event(event)
    ]


def clean_event(event: dict[str, Any]) -> dict[str, Any]:
    """Clean and normalize an event."""
    cleaned = dict(event)

    # Ensure numeric value
    if "value" in cleaned and cleaned["value"] is not None:
        try:
            cleaned["value"] = float(cleaned["value"])
        except (ValueError, TypeError):
            cleaned["value"] = 0.0

    # Ensure properties is a dict
    if not isinstance(cleaned.get("properties"), dict):
        cleaned["properties"] = {}

    return cleaned
