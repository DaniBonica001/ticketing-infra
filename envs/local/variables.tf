variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "ticketing-team"
}

variable "cost_center" {
  description = "CostCenter tag."
  type        = string
  default     = "local"
}

variable "lambda_package_path" {
  description = "Path to the expirer zip. Real artifact: ticketing-platform/ms-reservation-expirer/applications/app-service/build/distributions/ms-reservation-expirer.zip; a placeholder zip also works for infra-only checks."
  type        = string

  validation {
    condition     = endswith(var.lambda_package_path, ".zip")
    error_message = "lambda_package_path must point to a .zip file."
  }
}

variable "expirer_schedule_enabled" {
  description = "Enable the EventBridge schedule. Off by default so LocalStack does not spawn a java25 runtime container every minute (enable it with the real zip)."
  type        = bool
  default     = false
}
