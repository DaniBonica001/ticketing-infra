variable "name" {
  description = "Budget name."
  type        = string
  default     = "ticketing-monthly"
}

variable "monthly_limit_usd" {
  description = "Monthly cost limit in USD."
  type        = number

  validation {
    condition     = var.monthly_limit_usd > 0
    error_message = "monthly_limit_usd must be positive."
  }
}

variable "filter_by_project_tag" {
  description = "Scope the budget to resources tagged Project=<project_tag_value> (tag must be activated for cost allocation)."
  type        = bool
  default     = true
}

variable "project_tag_value" {
  description = "Value of the Project tag."
  type        = string
  default     = "ticketing"
}

variable "notifications" {
  description = "Notification thresholds (ACTUAL or FORECASTED, % of the limit)."
  type = list(object({
    type              = string
    threshold_percent = number
  }))
  default = [
    { type = "ACTUAL", threshold_percent = 80 },
    { type = "ACTUAL", threshold_percent = 100 },
    { type = "FORECASTED", threshold_percent = 100 },
  ]

  validation {
    condition     = alltrue([for n in var.notifications : contains(["ACTUAL", "FORECASTED"], n.type) && n.threshold_percent > 0])
    error_message = "notification type must be ACTUAL or FORECASTED with a positive threshold."
  }
}

variable "subscriber_emails" {
  description = "Emails notified by the budget."
  type        = list(string)

  validation {
    condition     = length(var.subscriber_emails) > 0 && length(var.subscriber_emails) <= 10
    error_message = "Provide between 1 and 10 subscriber emails."
  }
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
