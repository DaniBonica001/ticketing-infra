output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "Task definition ARN."
  value       = aws_ecs_task_definition.this.arn
}

output "log_group_name" {
  description = "Service log group name."
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "Service log group ARN."
  value       = aws_cloudwatch_log_group.this.arn
}
