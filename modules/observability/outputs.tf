output "alarm_topic_arn" {
  description = "SNS topic receiving all alarms."
  value       = aws_sns_topic.alarms.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "alarm_names" {
  description = "All alarm names created by the module."
  value = concat(
    [for a in aws_cloudwatch_metric_alarm.dlq_not_empty : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.queue_age : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.lambda : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.api_5xx : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.api_latency_p99 : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.dynamodb_throttles : a.alarm_name],
  )
}
