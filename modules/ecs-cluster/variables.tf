variable "name" {
  description = "Cluster name."
  type        = string

  validation {
    condition     = can(regex("^ticketing-[a-zA-Z0-9_-]{1,245}$", var.name))
    error_message = "name must start with 'ticketing-'."
  }
}

variable "container_insights" {
  description = "Container Insights mode: 'enhanced' (task/container level metrics) or 'enabled'."
  type        = string
  default     = "enhanced"

  validation {
    condition     = contains(["enhanced", "enabled"], var.container_insights)
    error_message = "container_insights must be 'enhanced' or 'enabled' (it is required by the per-task autoscaling metrics)."
  }
}

variable "logs_kms_key_arn" {
  description = "CMK for the ECS Exec audit log group and sessions."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:", var.logs_kms_key_arn))
    error_message = "logs_kms_key_arn must be a KMS key ARN."
  }
}

variable "log_retention_days" {
  description = "Retention of the ECS Exec audit log group."
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
