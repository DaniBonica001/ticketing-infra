# Module `lambda-scheduled`

Lambda function triggered by an EventBridge schedule (ADR-0005):

- Runtime `java25`, published versions + `live` alias (target of the schedule, required by SnapStart).
- `reserved_concurrent_executions = 1`: two sweeps never run at the same time.
- Optional VPC attachment (private subnets + SG) — always on in prod.
- SnapStart behind `snapstart_enabled` (confirm java25 support in the target region; off in LocalStack).
- JSON logs to a pre-created log group with retention and CMK; env vars encrypted with a CMK; X-Ray active.
- Async invoke config: 0 retries (the next tick retries), failures to an encrypted SQS **on-failure
  destination** (`<function>-failures`), which the observability module alarms on.
- EventBridge rule (`rate(1 minute)`), target with retry policy, and a `lambda:InvokeFunction`
  permission restricted to the rule ARN and the alias.

Outputs: `function_name`, `function_arn`, `alias_arn`, `log_group_arn`, `failures_queue_name`,
`failures_queue_arn`, `schedule_rule_name`, `schedule_rule_arn`.
