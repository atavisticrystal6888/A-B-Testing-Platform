# EventCollector

Event ingestion and buffering service for ExperimentHub.

Responsibilities:

- Validate inbound events
- Buffer events when Kafka is unavailable
- Produce validated events to configured Kafka producer modules
- Optionally run Broadway ingestion pipeline when `broadway_kafka` is present

Run focused tests:

```powershell
mix test apps/event_collector/test
```

