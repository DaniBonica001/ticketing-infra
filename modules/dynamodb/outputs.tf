output "table_name" {
  description = "Table name."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "Table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "index_arns" {
  description = "GSI ARNs by index name."
  value       = { for g in var.global_secondary_indexes : g.name => "${aws_dynamodb_table.this.arn}/index/${g.name}" }
}
