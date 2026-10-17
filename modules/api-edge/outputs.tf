output "rest_api_id" {
  description = "REST API ID."
  value       = aws_api_gateway_rest_api.this.id
}

output "rest_api_name" {
  description = "REST API name (ApiName dimension of the AWS/ApiGateway metrics)."
  value       = aws_api_gateway_rest_api.this.name
}

output "stage_name" {
  description = "Stage name (Stage dimension)."
  value       = aws_api_gateway_stage.this.stage_name
}

output "invoke_url" {
  description = "Public invoke URL of the stage."
  value       = aws_api_gateway_stage.this.invoke_url
}

output "target_group_arn" {
  description = "NLB target group where ms-ticketing-api tasks register."
  value       = aws_lb_target_group.api.arn
}

output "nlb_arn" {
  description = "Internal NLB ARN."
  value       = aws_lb.this.arn
}

output "nlb_arn_suffix" {
  description = "NLB ARN suffix (LoadBalancer dimension of AWS/NetworkELB metrics)."
  value       = aws_lb.this.arn_suffix
}

output "web_acl_arn" {
  description = "WAF web ACL ARN."
  value       = aws_wafv2_web_acl.this.arn
}
