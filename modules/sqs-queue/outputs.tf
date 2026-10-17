output "queue_name" {
  description = "Main queue name."
  value       = aws_sqs_queue.this.name
}

output "queue_arn" {
  description = "Main queue ARN."
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "Main queue URL (ORDERS_QUEUE_URL / CONFIRMATIONS_QUEUE_URL)."
  value       = aws_sqs_queue.this.url
}

output "dlq_name" {
  description = "DLQ name."
  value       = aws_sqs_queue.dlq.name
}

output "dlq_arn" {
  description = "DLQ ARN."
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "DLQ URL."
  value       = aws_sqs_queue.dlq.url
}
