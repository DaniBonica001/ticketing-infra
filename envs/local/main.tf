# ============================================================================================
# LocalStack 4.14 (community) composition: only services it emulates. Same modules and the same
# IAM policies as prod; ECS, ELBv2, WAF, API Gateway VPC link, VPC endpoints and Budgets are
# validated only (envs/prod). Differences vs prod are explicit below (deletion protection off,
# no VPC endpoint conditions, no VPC attachment, SnapStart off).
# ============================================================================================
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  names = {
    events_table           = "ticketing-events"
    orders_table           = "ticketing-orders"
    audit_table            = "ticketing-order-audit"
    orders_gsi             = "status-deadlineAt-index"
    orders_queue           = "ticketing-orders-queue"
    orders_dlq             = "ticketing-orders-dlq"
    confirmations_queue    = "ticketing-confirmations-queue"
    confirmations_dlq      = "ticketing-confirmations-dlq"
    payment_gateway_secret = "ticketing/payment-gateway"
    expirer_function       = "ticketing-reservation-expirer"
    expirer_schedule       = "ticketing-reservation-expirer-schedule"
  }
}

# --------------------------------------------------------------------------------------------
# KMS
# --------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "observability_key_services" {
  #checkov:skip=CKV_AWS_111:Key policy statements: "*" resource means this key only, scoped to service principals with conditions.
  #checkov:skip=CKV_AWS_356:Key policy statements: "*" resource means this key only.
  statement {
    sid       = "AllowCloudWatchLogs"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"] # In a key policy, "*" means "this key".

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarmsToEncryptedSns"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"] # In a key policy, "*" means "this key".

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
  }
}

module "kms" {
  source = "../../modules/kms"
  for_each = {
    data          = "Ticketing DynamoDB tables and Lambda environment"
    messaging     = "Ticketing SQS queues"
    secrets       = "Ticketing Secrets Manager secrets"
    observability = "Ticketing CloudWatch log groups and alarm topic"
  }

  alias                   = "ticketing-${each.key}"
  description             = each.value
  deletion_window_in_days = 7
  service_policy_json     = each.key == "observability" ? data.aws_iam_policy_document.observability_key_services.json : null
}

# --------------------------------------------------------------------------------------------
# DynamoDB (docs/design/dynamodb.md)
# --------------------------------------------------------------------------------------------
module "table_events" {
  source = "../../modules/dynamodb"

  name                        = local.names.events_table
  hash_key                    = "eventId"
  attributes                  = { eventId = "S" }
  kms_key_arn                 = module.kms["data"].key_arn
  deletion_protection_enabled = false
  point_in_time_recovery_days = null # LocalStack does not persist RecoveryPeriodInDays.
}

module "table_orders" {
  source = "../../modules/dynamodb"

  name       = local.names.orders_table
  hash_key   = "orderId"
  attributes = { orderId = "S", status = "S", deadlineAt = "N" }

  global_secondary_indexes = [{
    name            = local.names.orders_gsi
    hash_key        = "status"
    range_key       = "deadlineAt"
    projection_type = "ALL"
  }]

  kms_key_arn                 = module.kms["data"].key_arn
  deletion_protection_enabled = false
  point_in_time_recovery_days = null # LocalStack does not persist RecoveryPeriodInDays.
}

module "table_audit" {
  source = "../../modules/dynamodb"

  name                        = local.names.audit_table
  hash_key                    = "orderId"
  range_key                   = "transitionId"
  attributes                  = { orderId = "S", transitionId = "S" }
  kms_key_arn                 = module.kms["data"].key_arn
  deletion_protection_enabled = false
  point_in_time_recovery_days = null # LocalStack does not persist RecoveryPeriodInDays.
}

# --------------------------------------------------------------------------------------------
# SQS (ADR-0003 defaults) and Secrets Manager. No aws:SourceVpce conditions in LocalStack.
# --------------------------------------------------------------------------------------------
module "orders_queue" {
  source = "../../modules/sqs-queue"

  name               = local.names.orders_queue
  dlq_name           = local.names.orders_dlq
  kms_key_arn        = module.kms["messaging"].key_arn
  producer_role_arns = [module.role_api_task.role_arn, module.role_expirer.role_arn]
  consumer_role_arns = [module.role_processor_task.role_arn]
}

module "confirmations_queue" {
  source = "../../modules/sqs-queue"

  name               = local.names.confirmations_queue
  dlq_name           = local.names.confirmations_dlq
  kms_key_arn        = module.kms["messaging"].key_arn
  producer_role_arns = [module.role_api_task.role_arn, module.role_expirer.role_arn]
  consumer_role_arns = [module.role_processor_task.role_arn]
}

module "payment_gateway_secret" {
  source = "../../modules/secrets"

  name                    = local.names.payment_gateway_secret
  kms_key_arn             = module.kms["secrets"].key_arn
  recovery_window_in_days = 0
  reader_role_arns        = [module.role_processor_task.role_arn]
}

# --------------------------------------------------------------------------------------------
# IAM: same policies as prod (modules/component-policies).
# --------------------------------------------------------------------------------------------
module "policies" {
  source = "../../modules/component-policies"

  events_table_arn           = module.table_events.table_arn
  orders_table_arn           = module.table_orders.table_arn
  audit_table_arn            = module.table_audit.table_arn
  orders_gsi_arn             = module.table_orders.index_arns[local.names.orders_gsi]
  orders_queue_arn           = module.orders_queue.queue_arn
  confirmations_queue_arn    = module.confirmations_queue.queue_arn
  payment_gateway_secret_arn = module.payment_gateway_secret.secret_arn
  data_kms_key_arn           = module.kms["data"].key_arn
  messaging_kms_key_arn      = module.kms["messaging"].key_arn
  secrets_kms_key_arn        = module.kms["secrets"].key_arn
  expirer_failures_queue_arn = module.expirer.failures_queue_arn
  expirer_log_group_arn      = module.expirer.log_group_arn
  expirer_vpc_attached       = false
}

module "role_api_task" {
  source = "../../modules/iam-role"

  name               = "ticketing-api-task"
  description        = "ms-ticketing-api application permissions"
  trusted_services   = ["ecs-tasks.amazonaws.com"]
  inline_policy_json = module.policies.api_policy_json
}

module "role_processor_task" {
  source = "../../modules/iam-role"

  name               = "ticketing-processor-task"
  description        = "ms-order-processor application permissions"
  trusted_services   = ["ecs-tasks.amazonaws.com"]
  inline_policy_json = module.policies.processor_policy_json
}

module "role_expirer" {
  source = "../../modules/iam-role"

  name                       = "ticketing-expirer-lambda"
  description                = "ticketing-reservation-expirer execution role"
  trusted_services           = ["lambda.amazonaws.com"]
  restrict_to_source_account = false
  inline_policy_json         = module.policies.expirer_policy_json
}

# --------------------------------------------------------------------------------------------
# Lambda + EventBridge
# --------------------------------------------------------------------------------------------
module "expirer" {
  source = "../../modules/lambda-scheduled"

  function_name           = local.names.expirer_function
  description             = "Expires RESERVED orders past deadlineAt and reconciles stuck orders"
  role_arn                = module.role_expirer.role_arn
  runtime                 = "java25"
  handler                 = "com.dbonilla.ticketing.expirer.lambda.ExpirerHandler::handleRequest"
  package_path            = var.lambda_package_path
  memory_size             = 512
  timeout_seconds         = 60
  reserved_concurrency    = 1
  snapstart_enabled       = false # LocalStack does not emulate SnapStart.
  environment_kms_key_arn = null  # LocalStack does not echo KMSKeyArn back (perpetual diff); CMK in prod.
  messaging_kms_key_arn   = module.kms["messaging"].key_arn
  logs_kms_key_arn        = module.kms["observability"].key_arn
  log_retention_days      = 7
  schedule_name           = local.names.expirer_schedule
  schedule_expression     = "rate(1 minute)"
  schedule_enabled        = var.expirer_schedule_enabled

  # Inside LocalStack's Lambda container, the SDK reaches LocalStack through AWS_ENDPOINT_URL
  # injected by LocalStack itself; queue URLs are the ones LocalStack returns.
  environment = {
    EVENTS_TABLE            = module.table_events.table_name
    ORDERS_TABLE            = module.table_orders.table_name
    AUDIT_TABLE             = module.table_audit.table_name
    ORDERS_QUEUE_URL        = module.orders_queue.queue_url
    CONFIRMATIONS_QUEUE_URL = module.confirmations_queue.queue_url
    OTEL_SERVICE_NAME       = local.names.expirer_function
  }
}

# --------------------------------------------------------------------------------------------
# Observability (no API Gateway/ECS sections locally)
# --------------------------------------------------------------------------------------------
module "observability" {
  source = "../../modules/observability"

  name            = "ticketing"
  sns_kms_key_arn = module.kms["observability"].key_arn

  # LocalStack 4.14 bug: PutMetricAlarm succeeds but DescribeAlarms over the CBOR protocol used by
  # provider 6.x returns 500 ("unknown error ... serialize the response"), so the provider retries
  # until timeout. Alarms are validated in envs/prod and can be created locally with the AWS CLI.
  create_alarms = false

  dlq_names = [
    module.orders_queue.dlq_name,
    module.confirmations_queue.dlq_name,
    module.expirer.failures_queue_name,
  ]

  queue_max_age_seconds = {
    (module.orders_queue.queue_name)        = 60
    (module.confirmations_queue.queue_name) = 120
  }

  lambda_function_name = module.expirer.function_name
  dynamodb_table_names = [module.table_events.table_name, module.table_orders.table_name, module.table_audit.table_name]
}
