output "api_policy_json" {
  description = "ms-ticketing-api task role policy."
  value       = data.aws_iam_policy_document.api.json
}

output "processor_policy_json" {
  description = "ms-order-processor task role policy."
  value       = data.aws_iam_policy_document.processor.json
}

output "expirer_policy_json" {
  description = "ticketing-reservation-expirer execution role policy."
  value       = data.aws_iam_policy_document.expirer.json
}
