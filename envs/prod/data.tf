# Tables exactly as docs/design/dynamodb.md (application repo).
module "table_events" {
  source = "../../modules/dynamodb"

  name                        = local.names.events_table
  hash_key                    = "eventId"
  attributes                  = { eventId = "S" }
  kms_key_arn                 = module.kms_data.key_arn
  deletion_protection_enabled = var.deletion_protection_enabled
}

module "table_orders" {
  source = "../../modules/dynamodb"

  name     = local.names.orders_table
  hash_key = "orderId"
  attributes = {
    orderId    = "S"
    status     = "S"
    deadlineAt = "N"
  }

  # Sparse index: final orders have no deadlineAt, so only live orders are indexed.
  global_secondary_indexes = [{
    name            = local.names.orders_gsi
    hash_key        = "status"
    range_key       = "deadlineAt"
    projection_type = "ALL"
  }]

  kms_key_arn                 = module.kms_data.key_arn
  deletion_protection_enabled = var.deletion_protection_enabled
}

module "table_audit" {
  source = "../../modules/dynamodb"

  name      = local.names.audit_table
  hash_key  = "orderId"
  range_key = "transitionId"
  attributes = {
    orderId      = "S"
    transitionId = "S"
  }
  kms_key_arn                 = module.kms_data.key_arn
  deletion_protection_enabled = var.deletion_protection_enabled
}

# Queues: ADR-0003 parameters are the module defaults.
module "orders_queue" {
  source = "../../modules/sqs-queue"

  name                  = local.names.orders_queue
  dlq_name              = local.names.orders_dlq
  kms_key_arn           = module.kms_messaging.key_arn
  producer_role_arns    = [module.role_api_task.role_arn, module.role_expirer.role_arn]
  consumer_role_arns    = [module.role_processor_task.role_arn]
  break_glass_role_arns = var.break_glass_role_arns
  source_vpce_ids       = [module.network.interface_endpoint_ids["sqs"]]
}

module "confirmations_queue" {
  source = "../../modules/sqs-queue"

  name                  = local.names.confirmations_queue
  dlq_name              = local.names.confirmations_dlq
  kms_key_arn           = module.kms_messaging.key_arn
  producer_role_arns    = [module.role_api_task.role_arn, module.role_expirer.role_arn]
  consumer_role_arns    = [module.role_processor_task.role_arn]
  break_glass_role_arns = var.break_glass_role_arns
  source_vpce_ids       = [module.network.interface_endpoint_ids["sqs"]]
}

module "payment_gateway_secret" {
  source = "../../modules/secrets"

  name             = local.names.payment_gateway_secret
  description      = "Payment gateway API key ({\"apiKey\": \"...\"}); value set out-of-band."
  kms_key_arn      = module.kms_secrets.key_arn
  reader_role_arns = [module.role_processor_task.role_arn]
  source_vpce_ids  = [module.network.interface_endpoint_ids["secretsmanager"]]
}
