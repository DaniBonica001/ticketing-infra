output "secret_arn" {
  description = "Secret ARN."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Secret name (PAYMENT_GATEWAY_SECRET_ID)."
  value       = aws_secretsmanager_secret.this.name
}
