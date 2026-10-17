# Module `observability`

Alarms, alarm topic and dashboard (ADR-0007, "En AWS").

| Alarm | Condition |
|---|---|
| `<dlq>-not-empty` | DLQ / Lambda failure destination has ≥ 1 visible message |
| `<queue>-oldest-message-age` | `ApproximateAgeOfOldestMessage` above the per-queue threshold (2 of 3 min) |
| `<lambda>-errors` / `-throttles` | > 0 for 3 consecutive minutes |
| `<api>-5xx` | `5XXError` above `max_5xx_per_minute` (2 of 3 min) |
| `<api>-latency-p99` | `Latency` p99 above `p99_latency_ms` (3 of 5 min) |
| `<table>-throttles` | Read + Write throttle events > 0 (metric math) |

All alarms notify (ALARM and OK) a CMK-encrypted SNS topic that only CloudWatch (this account)
can publish to over TLS. Optional email subscriptions.

The dashboard `ticketing-overview` shows API, ECS, SQS, DLQs, DynamoDB and the Lambda.
API/ECS sections are omitted when their inputs are null (LocalStack).

Outputs: `alarm_topic_arn`, `dashboard_name`, `alarm_names`.
