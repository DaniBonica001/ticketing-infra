variable "name" {
  description = "Secret name (e.g. ticketing/payment-gateway)."
  type        = string

  validation {
    condition     = can(regex("^ticketing/[a-zA-Z0-9/_+=.@-]{1,500}$", var.name))
    error_message = "name must start with 'ticketing/'."
  }
}

variable "description" {
  description = "Secret description."
  type        = string
  default     = "Managed by Terraform; value is set out-of-band."
}

variable "kms_key_arn" {
  description = "Customer managed KMS key that encrypts the secret."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "recovery_window_in_days" {
  description = "Days before a deleted secret is purged (0 = immediate, only for local)."
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days == 0 || (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "reader_role_arns" {
  description = "Only these roles can GetSecretValue (everyone else is explicitly denied)."
  type        = list(string)

  validation {
    condition     = length(var.reader_role_arns) > 0
    error_message = "At least one reader role is required."
  }
}

variable "source_vpce_ids" {
  description = "Secrets Manager interface endpoint IDs readers must use. Empty disables the restriction (LocalStack)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
