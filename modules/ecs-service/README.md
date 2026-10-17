# Module `ecs-service`

Fargate service + task definition + autoscaling for one microservice.

Hardening:
- Private subnets only, `assign_public_ip = false`.
- `readonlyRootFilesystem = true`, non-root numeric user (`run_as_user`), all Linux capabilities dropped,
  `initProcessEnabled`; only an ephemeral `/tmp` is writable.
- Image **pinned by digest** (validated), separate task and execution roles, ECS Exec off.
- Deployment circuit breaker with automatic rollback.
- Log group with retention and CMK; `awslogs` in non-blocking mode.

Autoscaling:
- Target tracking on average CPU (always).
- Optional `per_task_scaling`: target tracking on `metric / RunningTaskCount` (metric math), used for
  API Gateway `Count` per task (API) and SQS `ApproximateNumberOfMessagesVisible` per task (processor).

Outputs: `service_name`, `task_definition_arn`, `log_group_name`, `log_group_arn`.
