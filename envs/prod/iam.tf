# One role per component, least privilege. The application policies are rendered by
# modules/component-policies (shared with envs/local); execution roles are prod-only.
module "policies" {
  source = "../../modules/component-policies"

  events_table_arn           = module.table_events.table_arn
  orders_table_arn           = module.table_orders.table_arn
  audit_table_arn            = module.table_audit.table_arn
  orders_gsi_arn             = module.table_orders.index_arns[local.names.orders_gsi]
  orders_queue_arn           = module.orders_queue.queue_arn
  confirmations_queue_arn    = module.confirmations_queue.queue_arn
  payment_gateway_secret_arn = module.payment_gateway_secret.secret_arn
  data_kms_key_arn           = module.kms_data.key_arn
  messaging_kms_key_arn      = module.kms_messaging.key_arn
  secrets_kms_key_arn        = module.kms_secrets.key_arn
  expirer_failures_queue_arn = module.expirer.failures_queue_arn
  expirer_log_group_arn      = module.expirer.log_group_arn
  expirer_vpc_attached       = true
}

module "role_api_task" {
  source = "../../modules/iam-role"

  name                     = "ticketing-api-task"
  description              = "ms-ticketing-api application permissions"
  trusted_services         = ["ecs-tasks.amazonaws.com"]
  inline_policy_json       = module.policies.api_policy_json
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "role_processor_task" {
  source = "../../modules/iam-role"

  name                     = "ticketing-processor-task"
  description              = "ms-order-processor application permissions"
  trusted_services         = ["ecs-tasks.amazonaws.com"]
  inline_policy_json       = module.policies.processor_policy_json
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "role_expirer" {
  source = "../../modules/iam-role"

  name                       = "ticketing-expirer-lambda"
  description                = "ticketing-reservation-expirer execution role"
  trusted_services           = ["lambda.amazonaws.com"]
  restrict_to_source_account = false
  inline_policy_json         = module.policies.expirer_policy_json
  permissions_boundary_arn   = var.permissions_boundary_arn
}

# --------------------------------------------------------------------------------------------
# ECS execution roles (one per service): image pull + log delivery only.
# --------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "execution" {
  for_each = {
    api       = { repo = aws_ecr_repository.this[local.names.api_service].arn, log_group = module.svc_api.log_group_arn }
    processor = { repo = aws_ecr_repository.this[local.names.processor_service].arn, log_group = module.svc_processor.log_group_arn }
  }

  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # GetAuthorizationToken does not support resource-level permissions.
  }

  statement {
    sid       = "PullOwnImage"
    actions   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
    resources = [each.value.repo]
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${each.value.log_group}:*"]
  }
}

module "role_api_execution" {
  source = "../../modules/iam-role"

  name                     = "ticketing-api-execution"
  description              = "ECS agent permissions for ms-ticketing-api"
  trusted_services         = ["ecs-tasks.amazonaws.com"]
  inline_policy_json       = data.aws_iam_policy_document.execution["api"].json
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "role_processor_execution" {
  source = "../../modules/iam-role"

  name                     = "ticketing-processor-execution"
  description              = "ECS agent permissions for ms-order-processor"
  trusted_services         = ["ecs-tasks.amazonaws.com"]
  inline_policy_json       = data.aws_iam_policy_document.execution["processor"].json
  permissions_boundary_arn = var.permissions_boundary_arn
}
