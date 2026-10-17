variable "alias" {
  description = "Key alias without the 'alias/' prefix (e.g. ticketing-data)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9/_-]{1,250}$", var.alias)) && !startswith(var.alias, "aws/")
    error_message = "alias must contain only alphanumerics, '/', '_' or '-' and must not start with 'aws/'."
  }
}

variable "description" {
  description = "Human readable purpose of the key."
  type        = string

  validation {
    condition     = length(var.description) > 0
    error_message = "description must not be empty."
  }
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled key deletion is executed."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "rotation_period_in_days" {
  description = "Automatic key material rotation period."
  type        = number
  default     = 365

  validation {
    condition     = var.rotation_period_in_days >= 90 && var.rotation_period_in_days <= 2560
    error_message = "rotation_period_in_days must be between 90 and 2560."
  }
}

variable "admin_principal_arns" {
  description = "IAM principals allowed to administer (not use) the key. Empty = administration only through IAM delegation."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.admin_principal_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:", arn))])
    error_message = "admin_principal_arns must be IAM ARNs."
  }
}

variable "service_policy_json" {
  description = "Optional extra key policy statements (JSON) for AWS service principals, e.g. CloudWatch Logs."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags for the key."
  type        = map(string)
  default     = {}
}
