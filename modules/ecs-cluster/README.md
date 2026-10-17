# Module `ecs-cluster`

ECS cluster for Fargate workloads:

- Container Insights (`enhanced` by default) — required by the per-task autoscaling metric math in `ecs-service`.
- Capacity providers `FARGATE` (default, base 1) and `FARGATE_SPOT` (opt-in per service, e.g. the processor).
- ECS Exec sessions (disabled on services by default) encrypted with a CMK and logged to an encrypted log group.

Outputs: `cluster_name`, `cluster_arn`.
