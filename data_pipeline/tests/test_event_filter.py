"""Unit tests for data pipeline event filtering helpers."""

from src.transforms.event_filter import clean_event, filter_events


def test_filter_events_discards_bots_and_invalid_records():
    valid_event = {
        "tenant_id": "tenant-1",
        "experiment_id": "experiment-1",
        "user_id": "user-1",
        "event_type": "conversion",
        "event_name": "checkout",
    }

    filtered = filter_events(
        [
            valid_event,
            {**valid_event, "user_id": "bot-user", "is_bot": True},
            {"tenant_id": "tenant-1", "experiment_id": "experiment-1"},
        ]
    )

    assert filtered == [valid_event]


def test_clean_event_normalizes_numeric_value_and_properties():
    cleaned = clean_event({
        "value": "12.5",
        "properties": "not-a-map",
    })

    assert cleaned["value"] == 12.5
    assert cleaned["properties"] == {}
