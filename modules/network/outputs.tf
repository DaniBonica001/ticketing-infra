output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ)."
  value       = [for s in aws_subnet.private : s.id]
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks (one per AZ)."
  value       = [for s in aws_subnet.private : s.cidr_block]
}

output "security_group_ids" {
  description = "Security group IDs by role: api, processor, lambda, nlb, endpoints."
  value = {
    api       = aws_security_group.app["api"].id
    processor = aws_security_group.app["processor"].id
    lambda    = aws_security_group.app["lambda"].id
    nlb       = aws_security_group.nlb.id
    endpoints = aws_security_group.endpoints.id
  }
}

output "interface_endpoint_ids" {
  description = "Interface endpoint IDs by service suffix (used in aws:SourceVpce conditions)."
  value       = { for k, e in aws_vpc_endpoint.interface : k => e.id }
}

output "dynamodb_endpoint_id" {
  description = "DynamoDB gateway endpoint ID."
  value       = aws_vpc_endpoint.dynamodb.id
}

output "flow_logs_log_group_name" {
  description = "Flow logs log group."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
