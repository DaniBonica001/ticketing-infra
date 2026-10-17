output "api_invoke_url" {
  description = "Public API URL (WAF-protected)."
  value       = module.edge.invoke_url
}

output "orders_queue_url" {
  description = "ORDERS_QUEUE_URL."
  value       = module.orders_queue.queue_url
}

output "confirmations_queue_url" {
  description = "CONFIRMATIONS_QUEUE_URL."
  value       = module.confirmations_queue.queue_url
}

output "table_names" {
  description = "EVENTS_TABLE / ORDERS_TABLE / AUDIT_TABLE."
  value = {
    events = module.table_events.table_name
    orders = module.table_orders.table_name
    audit  = module.table_audit.table_name
  }
}

output "payment_gateway_secret_id" {
  description = "PAYMENT_GATEWAY_SECRET_ID (value set out-of-band)."
  value       = module.payment_gateway_secret.secret_name
}

output "ecr_repository_urls" {
  description = "ECR repositories to push images to (deploy by digest)."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "expirer_function_name" {
  description = "Lambda function name."
  value       = module.expirer.function_name
}

output "alarm_topic_arn" {
  description = "SNS topic for alarms."
  value       = module.observability.alarm_topic_arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard."
  value       = module.observability.dashboard_name
}
