# --------------------------------------------------------------------------------------------
# ECR: immutable tags, scan on push, CMK encryption. Images are deployed by digest.
# --------------------------------------------------------------------------------------------
resource "aws_ecr_repository" "this" {
  for_each = toset([local.names.api_service, local.names.processor_service])

  name                 = "ticketing/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = module.kms_data.key_arn
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 30 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
      action       = { type = "expire" }
    }]
  })
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name             = local.names.cluster
  logs_kms_key_arn = module.kms_observability.key_arn
}

locals {
  common_app_env = {
    AWS_REGION   = local.region
    EVENTS_TABLE = module.table_events.table_name
    ORDERS_TABLE = module.table_orders.table_name
    AUDIT_TABLE  = module.table_audit.table_name
  }
}

module "svc_api" {
  source = "../../modules/ecs-service"

  name               = local.names.api_service
  cluster_name       = module.ecs_cluster.cluster_name
  cluster_arn        = module.ecs_cluster.cluster_arn
  image              = var.api_image
  cpu                = 1024
  memory             = 2048
  container_port     = local.api_port
  management_port    = local.management_port
  task_role_arn      = module.role_api_task.role_arn
  execution_role_arn = module.role_api_execution.role_arn
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.security_group_ids["api"]]
  load_balancer      = { target_group_arn = module.edge.target_group_arn }
  logs_kms_key_arn   = module.kms_observability.key_arn
  log_retention_days = var.log_retention_days

  environment = merge(local.common_app_env, {
    ORDERS_QUEUE_URL        = module.orders_queue.queue_url
    CONFIRMATIONS_QUEUE_URL = module.confirmations_queue.queue_url
    JWT_ISSUER              = var.jwt_issuer
    JWT_AUDIENCE            = var.jwt_audience
    JWT_PUBLIC_KEY_LOCATION = var.jwt_public_key_location
    OTEL_SERVICE_NAME       = local.names.api_service
    # The internal NLB lives in the private subnets: only from there is X-Client-Ip (set by API Gateway)
    # trusted as the client IP for the per-IP rate limit.
    TICKETING_RATE_LIMIT_TRUSTED_PROXIES = join(",", module.network.private_subnet_cidrs)
  })

  autoscaling = {
    min_capacity       = var.api_autoscaling.min_capacity
    max_capacity       = var.api_autoscaling.max_capacity
    cpu_target_percent = var.api_autoscaling.cpu_target_percent
  }

  per_task_scaling = {
    requests = {
      namespace       = "AWS/ApiGateway"
      metric_name     = "Count"
      statistic       = "Sum"
      dimensions      = { ApiName = module.edge.rest_api_name, Stage = module.edge.stage_name }
      target_per_task = var.api_autoscaling.requests_per_task_per_min
    }
  }
}

module "svc_processor" {
  source = "../../modules/ecs-service"

  name               = local.names.processor_service
  cluster_name       = module.ecs_cluster.cluster_name
  cluster_arn        = module.ecs_cluster.cluster_arn
  image              = var.processor_image
  cpu                = 512
  memory             = 1024
  task_role_arn      = module.role_processor_task.role_arn
  execution_role_arn = module.role_processor_execution.role_arn
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.network.security_group_ids["processor"]]
  logs_kms_key_arn   = module.kms_observability.key_arn
  log_retention_days = var.log_retention_days

  # Spot is safe for the processor: messages are redelivered after the visibility timeout and the
  # consumers are idempotent. The on-demand base keeps a floor during Spot reclaims.
  capacity_provider_strategy = var.processor_autoscaling.use_fargate_spot ? [
    { capacity_provider = "FARGATE", weight = 1, base = var.processor_autoscaling.on_demand_base_tasks },
    { capacity_provider = "FARGATE_SPOT", weight = 3, base = 0 },
  ] : [{ capacity_provider = "FARGATE", weight = 1, base = 1 }]

  environment = merge(local.common_app_env, {
    ORDERS_QUEUE_URL          = module.orders_queue.queue_url
    CONFIRMATIONS_QUEUE_URL   = module.confirmations_queue.queue_url
    PAYMENT_GATEWAY_SECRET_ID = module.payment_gateway_secret.secret_name
    OTEL_SERVICE_NAME         = local.names.processor_service
  })

  autoscaling = {
    min_capacity       = var.processor_autoscaling.min_capacity
    max_capacity       = var.processor_autoscaling.max_capacity
    cpu_target_percent = var.processor_autoscaling.cpu_target_percent
  }

  # One backlog-per-task policy per queue: a slow payment gateway (confirmations) scales the
  # processor without waiting for the orders queue, and vice versa.
  per_task_scaling = {
    orders-backlog = {
      namespace       = "AWS/SQS"
      metric_name     = "ApproximateNumberOfMessagesVisible"
      statistic       = "Sum"
      dimensions      = { QueueName = module.orders_queue.queue_name }
      target_per_task = var.processor_autoscaling.backlog_per_task
    }
    confirmations-backlog = {
      namespace       = "AWS/SQS"
      metric_name     = "ApproximateNumberOfMessagesVisible"
      statistic       = "Sum"
      dimensions      = { QueueName = module.confirmations_queue.queue_name }
      target_per_task = var.processor_autoscaling.backlog_per_task
    }
  }
}

module "expirer" {
  source = "../../modules/lambda-scheduled"

  function_name           = local.names.expirer_function
  description             = "Expires RESERVED orders past deadlineAt and reconciles stuck QUEUED/PENDING_CONFIRMATION orders"
  role_arn                = module.role_expirer.role_arn
  runtime                 = "java25"
  handler                 = "com.dbonilla.ticketing.expirer.lambda.ExpirerHandler::handleRequest"
  package_path            = var.lambda_package_path
  memory_size             = 512
  timeout_seconds         = 60
  reserved_concurrency    = 1
  snapstart_enabled       = var.lambda_snapstart_enabled
  subnet_ids              = module.network.private_subnet_ids
  security_group_ids      = [module.network.security_group_ids["lambda"]]
  environment_kms_key_arn = module.kms_data.key_arn
  messaging_kms_key_arn   = module.kms_messaging.key_arn
  logs_kms_key_arn        = module.kms_observability.key_arn
  log_retention_days      = var.log_retention_days
  schedule_name           = local.names.expirer_schedule
  schedule_expression     = "rate(1 minute)"

  environment = {
    EVENTS_TABLE            = module.table_events.table_name
    ORDERS_TABLE            = module.table_orders.table_name
    AUDIT_TABLE             = module.table_audit.table_name
    ORDERS_QUEUE_URL        = module.orders_queue.queue_url
    CONFIRMATIONS_QUEUE_URL = module.confirmations_queue.queue_url
    OTEL_SERVICE_NAME       = local.names.expirer_function
  }
}
