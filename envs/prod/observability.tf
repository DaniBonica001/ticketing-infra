module "observability" {
  source = "../../modules/observability"

  name            = "ticketing"
  sns_kms_key_arn = module.kms_observability.key_arn
  alarm_emails    = var.alarm_emails

  dlq_names = [
    module.orders_queue.dlq_name,
    module.confirmations_queue.dlq_name,
    module.expirer.failures_queue_name,
  ]

  # Orders should be reserved within seconds; confirmations depend on the payment gateway.
  queue_max_age_seconds = {
    (module.orders_queue.queue_name)        = 60
    (module.confirmations_queue.queue_name) = 120
  }

  lambda_function_name = module.expirer.function_name
  dynamodb_table_names = [module.table_events.table_name, module.table_orders.table_name, module.table_audit.table_name]

  api = {
    name               = module.edge.rest_api_name
    stage              = module.edge.stage_name
    max_5xx_per_minute = 5
    p99_latency_ms     = 1000
  }

  ecs_cluster_name = module.ecs_cluster.cluster_name
  ecs_services     = [module.svc_api.service_name, module.svc_processor.service_name]
}

module "budget" {
  source = "../../modules/budget"

  name              = "ticketing-${var.environment}-monthly"
  monthly_limit_usd = var.budget_monthly_limit_usd
  subscriber_emails = var.budget_emails
}
