data "aws_region" "current" {}

locals {
  tmp_volume_name = "tmp"

  port_mappings = [
    for port in [var.container_port, var.management_port] : {
      containerPort = port
      protocol      = "tcp"
    } if port != null
  ]

  container_definition = {
    name                   = var.name
    image                  = var.image
    essential              = true
    readonlyRootFilesystem = true
    user                   = var.run_as_user
    privileged             = false
    portMappings           = local.port_mappings
    environment            = [for k, v in var.environment : { name = k, value = v }]
    stopTimeout            = var.stop_timeout_seconds

    linuxParameters = {
      initProcessEnabled = true
      capabilities = {
        drop = ["ALL"]
      }
    }

    # Read-only root FS: the JVM and Netty only get a writable, ephemeral /tmp.
    mountPoints = [{
      sourceVolume  = local.tmp_volume_name
      containerPath = "/tmp"
      readOnly      = false
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = var.name
        mode                  = "non-blocking"
        max-buffer-size       = "25m"
      }
    }
  }

  resource_id = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/ticketing/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = var.tags
}

resource "aws_ecs_task_definition" "this" {
  #checkov:skip=CKV_AWS_249:Task and execution roles are always different roles (separate iam-role modules per service); the scanner cannot resolve module outputs.
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn            = var.task_role_arn
  execution_role_arn       = var.execution_role_arn
  container_definitions    = jsonencode([local.container_definition])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  volume {
    name = local.tmp_volume_name
  }

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = var.cluster_arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.autoscaling.min_capacity
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_execute_command             = false
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"
  health_check_grace_period_seconds  = var.load_balancer == null ? null : var.health_check_grace_period_seconds
  wait_for_steady_state              = false

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy

    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer == null ? [] : [var.load_balancer]

    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # Autoscaling owns the running count after the first deployment.
    ignore_changes = [desired_count]
  }

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_appautoscaling_target" "this" {
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = local.resource_id
  min_capacity       = var.autoscaling.min_capacity
  max_capacity       = var.autoscaling.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = var.autoscaling.cpu_target_percent
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown_seconds
    scale_out_cooldown = var.autoscaling.scale_out_cooldown_seconds

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Per-task target tracking on an external metric (metric math: metric / RunningTaskCount).
# Used for API Gateway requests per task (API) and SQS backlog per task (processor), following
# the AWS "backlog per instance" pattern.
resource "aws_appautoscaling_policy" "per_task" {
  for_each = var.per_task_scaling

  name               = "${var.name}-${each.key}-per-task"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this.service_namespace
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  resource_id        = aws_appautoscaling_target.this.resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_per_task
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown_seconds
    scale_out_cooldown = var.autoscaling.scale_out_cooldown_seconds

    customized_metric_specification {
      metrics {
        id          = "load"
        label       = each.value.metric_name
        return_data = false

        metric_stat {
          stat = each.value.statistic

          metric {
            namespace   = each.value.namespace
            metric_name = each.value.metric_name

            dynamic "dimensions" {
              for_each = each.value.dimensions

              content {
                name  = dimensions.key
                value = dimensions.value
              }
            }
          }
        }
      }

      metrics {
        id          = "tasks"
        label       = "RunningTaskCount"
        return_data = false

        metric_stat {
          stat = "Average"

          metric {
            namespace   = "ECS/ContainerInsights"
            metric_name = "RunningTaskCount"

            dimensions {
              name  = "ClusterName"
              value = var.cluster_name
            }

            dimensions {
              name  = "ServiceName"
              value = aws_ecs_service.this.name
            }
          }
        }
      }

      metrics {
        id          = "per_task"
        label       = "${each.value.metric_name} per task"
        expression  = "load / IF(tasks > 0, tasks, 1)"
        return_data = true
      }
    }
  }
}
