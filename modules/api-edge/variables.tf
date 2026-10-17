variable "name" {
  description = "Name prefix for the edge resources (REST API name)."
  type        = string
  default     = "ticketing-api"

  validation {
    condition     = can(regex("^ticketing-[a-z0-9-]{1,20}$", var.name))
    error_message = "name must start with 'ticketing-' and be short (NLB/TG names are limited to 32 chars)."
  }
}

variable "stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "v1"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.stage_name))
    error_message = "stage_name must be alphanumeric, '-' or '_'."
  }
}

variable "vpc_id" {
  description = "VPC of the NLB and the API tasks."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the internal NLB."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnets are required."
  }
}

variable "nlb_security_group_id" {
  description = "Security group of the NLB (egress only to the API SG)."
  type        = string
}

variable "listener_port" {
  description = "NLB listener port used by the VPC link integration."
  type        = number
  default     = 80
}

variable "api_port" {
  description = "ms-ticketing-api container port (target group port)."
  type        = number
  default     = 8080
}

variable "api_health_port" {
  description = "Actuator port for the target group health check."
  type        = number
  default     = 9090
}

variable "api_health_path" {
  description = "Readiness endpoint for the health check."
  type        = string
  default     = "/actuator/health/readiness"
}

variable "integration_timeout_ms" {
  description = "Integration timeout. The API answers 202 in milliseconds; long waits indicate trouble."
  type        = number
  default     = 10000

  validation {
    condition     = var.integration_timeout_ms >= 50 && var.integration_timeout_ms <= 29000
    error_message = "integration_timeout_ms must be between 50 and 29000."
  }
}

variable "throttling_rate_limit" {
  description = "Stage steady-state requests per second (all clients)."
  type        = number
  default     = 2000

  validation {
    condition     = var.throttling_rate_limit > 0
    error_message = "throttling_rate_limit must be positive."
  }
}

variable "throttling_burst_limit" {
  description = "Stage burst capacity (token bucket)."
  type        = number
  default     = 4000

  validation {
    condition     = var.throttling_burst_limit > 0
    error_message = "throttling_burst_limit must be positive."
  }
}

variable "waf_rate_limit_per_5min" {
  description = "Maximum requests per client IP in a 5-minute window before WAF blocks it."
  type        = number
  default     = 1000

  validation {
    condition     = var.waf_rate_limit_per_5min >= 10 && var.waf_rate_limit_per_5min <= 2000000000
    error_message = "waf_rate_limit_per_5min must be between 10 and 2e9."
  }
}

variable "cognito_user_pool_arns" {
  description = "Cognito user pools for an edge authorizer (production option). Empty = JWT validated only in the service."
  type        = list(string)
  default     = []
}

variable "manage_account_cloudwatch_role" {
  description = "Create the account/region singleton API Gateway CloudWatch role (only one stack per account should)."
  type        = bool
  default     = true
}

variable "deletion_protection_enabled" {
  description = "NLB deletion protection."
  type        = bool
  default     = true
}

variable "logs_kms_key_arn" {
  description = "CMK for access and WAF log groups."
  type        = string
}

variable "log_retention_days" {
  description = "Retention for access and WAF logs (1 year: security investigations)."
  type        = number
  default     = 365

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs."
  }
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
