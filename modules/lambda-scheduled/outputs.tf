output "function_name" {
  description = "Function name."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Unqualified function ARN."
  value       = aws_lambda_function.this.arn
}

output "alias_arn" {
  description = "ARN of the 'live' alias invoked by the schedule."
  value       = aws_lambda_alias.live.arn
}

output "log_group_arn" {
  description = "Function log group ARN."
  value       = aws_cloudwatch_log_group.this.arn
}

output "failures_queue_name" {
  description = "Async failure destination queue name."
  value       = aws_sqs_queue.failures.name
}

output "failures_queue_arn" {
  description = "Async failure destination queue ARN."
  value       = aws_sqs_queue.failures.arn
}

output "schedule_rule_name" {
  description = "EventBridge rule name."
  value       = aws_cloudwatch_event_rule.schedule.name
}

output "schedule_rule_arn" {
  description = "EventBridge rule ARN."
  value       = aws_cloudwatch_event_rule.schedule.arn
}
