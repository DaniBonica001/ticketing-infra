variable "environment" {
  description = "Environment name (also the Environment tag)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "allowed_account_ids" {
  description = "The only AWS account(s) this configuration may touch (prod workload account)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_account_ids) > 0 && alltrue([for a in var.allowed_account_ids : can(regex("^[0-9]{12}$", a))])
    error_message = "allowed_account_ids must contain 12-digit account IDs."
  }
}

variable "owner" {
  description = "Owner tag (team or person accountable)."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag for chargeback."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR (unique across the organization's VPCs)."
  type        = string
  default     = "10.40.0.0/16"
}

variable "az_count" {
  description = "Number of AZs (3 in prod, 2 in dev/staging)."
  type        = number
  default     = 3
}

variable "payment_gateway_cidrs" {
  description = "Payment gateway CIDRs reachable by the processor (PrivateLink endpoint or egress VPC)."
  type        = list(string)
  default     = []
}

variable "api_image" {
  description = "ms-ticketing-api image pinned by digest (…@sha256:…)."
  type        = string
}

variable "processor_image" {
  description = "ms-order-processor image pinned by digest (…@sha256:…)."
  type        = string
}

variable "lambda_package_path" {
  description = "Path to ms-reservation-expirer.zip (built by the application repo CI)."
  type        = string
  default     = "../../../ticketing-platform/ms-reservation-expirer/applications/app-service/build/distributions/ms-reservation-expirer.zip"
}

variable "lambda_snapstart_enabled" {
  description = "Enable SnapStart on the expirer. Off by default (application team recommendation): a 1-minute schedule keeps the function warm, and java25 support must be confirmed per region first."
  type        = bool
  default     = false
}

variable "jwt_issuer" {
  description = "Expected JWT issuer (iss)."
  type        = string
}

variable "jwt_audience" {
  description = "Expected JWT audience (aud)."
  type        = string
  default     = "ticketing-api"
}

variable "jwt_public_key_location" {
  description = "Location of the IdP public key / JWKS used by the API."
  type        = string
}

variable "cognito_user_pool_arns" {
  description = "Optional Cognito user pools for an edge authorizer."
  type        = list(string)
  default     = []
}

variable "api_autoscaling" {
  description = "API autoscaling: bounds, CPU target and API Gateway requests per task per minute."
  type = object({
    min_capacity              = number
    max_capacity              = number
    cpu_target_percent        = number
    requests_per_task_per_min = number
  })
  default = {
    min_capacity              = 3
    max_capacity              = 30
    cpu_target_percent        = 60
    requests_per_task_per_min = 6000
  }
}

variable "processor_autoscaling" {
  description = "Processor autoscaling: bounds, CPU target and SQS backlog (visible messages) per task."
  type = object({
    min_capacity         = number
    max_capacity         = number
    cpu_target_percent   = number
    backlog_per_task     = number
    use_fargate_spot     = bool
    on_demand_base_tasks = number
  })
  default = {
    min_capacity         = 2
    max_capacity         = 40
    cpu_target_percent   = 60
    backlog_per_task     = 200
    use_fargate_spot     = true
    on_demand_base_tasks = 2
  }
}

variable "api_throttling" {
  description = "API Gateway stage throttling and WAF per-IP rate limit."
  type = object({
    rate_limit           = number
    burst_limit          = number
    waf_per_ip_per_5_min = number
  })
  default = {
    rate_limit           = 2000
    burst_limit          = 4000
    waf_per_ip_per_5_min = 1000
  }
}

variable "deletion_protection_enabled" {
  description = "Deletion protection for DynamoDB tables and the NLB."
  type        = bool
  default     = true
}

variable "kms_admin_role_arns" {
  description = "Roles allowed to administer the CMKs (platform/security team)."
  type        = list(string)
  default     = []
}

variable "break_glass_role_arns" {
  description = "Operator roles exempted from the SQS producer/consumer deny statements (DLQ redrive)."
  type        = list(string)
  default     = []
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary applied to every component role."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Retention for application logs (1 year in prod)."
  type        = number
  default     = 365
}

variable "alarm_emails" {
  description = "Emails subscribed to the alarm topic."
  type        = list(string)
  default     = []
}

variable "budget_monthly_limit_usd" {
  description = "Monthly budget for the project."
  type        = number
  default     = 1500
}

variable "budget_emails" {
  description = "Emails notified by the budget."
  type        = list(string)
}
