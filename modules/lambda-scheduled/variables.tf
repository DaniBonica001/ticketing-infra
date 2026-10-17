variable "function_name" {
  description = "Lambda function name."
  type        = string

  validation {
    condition     = can(regex("^ticketing-[a-zA-Z0-9_-]{1,45}$", var.function_name))
    error_message = "function_name must start with 'ticketing-' and leave room for the '-failures' suffix."
  }
}

variable "description" {
  description = "Function description."
  type        = string
  default     = ""
}

variable "role_arn" {
  description = "Execution role ARN."
  type        = string
}

variable "runtime" {
  description = "Managed runtime."
  type        = string
  default     = "java25"
}

variable "handler" {
  description = "Handler (class::method)."
  type        = string
}

variable "architecture" {
  description = "arm64 (cheaper per GB-s) or x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.architecture)
    error_message = "architecture must be arm64 or x86_64."
  }
}

variable "package_path" {
  description = "Path to the deployment zip (built by the application repo)."
  type        = string

  validation {
    condition     = endswith(var.package_path, ".zip")
    error_message = "package_path must point to a .zip file."
  }
}

variable "memory_size" {
  description = "Memory in MB (also scales CPU)."
  type        = number
  default     = 512

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240."
  }
}

variable "timeout_seconds" {
  description = "Function timeout; must stay below the schedule period (60 s)."
  type        = number
  default     = 60

  validation {
    condition     = var.timeout_seconds >= 1 && var.timeout_seconds <= 900
    error_message = "timeout_seconds must be between 1 and 900."
  }
}

variable "reserved_concurrency" {
  description = "Reserved concurrency (ADR-0005: 1, so sweeps never overlap)."
  type        = number
  default     = 1

  validation {
    condition     = var.reserved_concurrency >= 1
    error_message = "reserved_concurrency must be at least 1."
  }
}

variable "environment" {
  description = "Environment variables (non-secret)."
  type        = map(string)
  default     = {}
}

variable "environment_kms_key_arn" {
  description = "CMK that encrypts the environment variables at rest (null = AWS managed key; only for LocalStack, which does not return KMSKeyArn and would show a perpetual diff)."
  type        = string
  default     = null
}

variable "messaging_kms_key_arn" {
  description = "CMK for the failure-destination queue."
  type        = string
}

variable "logs_kms_key_arn" {
  description = "CMK for the log group."
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs."
  }
}

variable "tracing_mode" {
  description = "X-Ray tracing mode."
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be Active or PassThrough."
  }
}

variable "subnet_ids" {
  description = "Private subnets (empty = not VPC-attached, only for LocalStack)."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Security groups for the function ENIs."
  type        = list(string)
  default     = []
}

variable "snapstart_enabled" {
  description = "Enable SnapStart on published versions (see the comment in main.tf)."
  type        = bool
  default     = false
}

variable "async_retry_attempts" {
  description = "Async retries before sending the event to the failure destination."
  type        = number
  default     = 0

  validation {
    condition     = var.async_retry_attempts >= 0 && var.async_retry_attempts <= 2
    error_message = "async_retry_attempts must be between 0 and 2."
  }
}

variable "async_max_event_age_seconds" {
  description = "Maximum age of an async event before it is discarded to the destination."
  type        = number
  default     = 120

  validation {
    condition     = var.async_max_event_age_seconds >= 60 && var.async_max_event_age_seconds <= 21600
    error_message = "async_max_event_age_seconds must be between 60 and 21600."
  }
}

variable "schedule_name" {
  description = "EventBridge rule name."
  type        = string
}

variable "schedule_expression" {
  description = "EventBridge schedule expression."
  type        = string
  default     = "rate(1 minute)"

  validation {
    condition     = can(regex("^(rate|cron)\\(.+\\)$", var.schedule_expression))
    error_message = "schedule_expression must be rate(...) or cron(...)."
  }
}

variable "schedule_enabled" {
  description = "Whether the schedule is enabled."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
