output "table_names" {
  description = "EVENTS_TABLE / ORDERS_TABLE / AUDIT_TABLE."
  value = {
    events = module.table_events.table_name
    orders = module.table_orders.table_name
    audit  = module.table_audit.table_name
  }
}

output "orders_queue_url" {
  description = "ORDERS_QUEUE_URL."
  value       = module.orders_queue.queue_url
}

output "confirmations_queue_url" {
  description = "CONFIRMATIONS_QUEUE_URL."
  value       = module.confirmations_queue.queue_url
}

output "payment_gateway_secret_id" {
  description = "PAYMENT_GATEWAY_SECRET_ID."
  value       = module.payment_gateway_secret.secret_name
}

output "expirer_function_name" {
  description = "Lambda function name."
  value       = module.expirer.function_name
}

output "expirer_schedule_rule" {
  description = "EventBridge rule name."
  value       = module.expirer.schedule_rule_name
}

output "alarm_names" {
  description = "CloudWatch alarms."
  value       = module.observability.alarm_names
}
