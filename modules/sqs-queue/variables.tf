variable "name" {
  description = "Main (standard) queue name."
  type        = string

  validation {
    condition     = can(regex("^ticketing-[a-zA-Z0-9_-]{1,70}$", var.name))
    error_message = "name must start with 'ticketing-' and be at most 80 characters (no .fifo: ADR-0003 uses standard queues)."
  }
}

variable "dlq_name" {
  description = "Dead-letter queue name."
  type        = string

  validation {
    condition     = can(regex("^ticketing-[a-zA-Z0-9_-]{1,70}$", var.dlq_name))
    error_message = "dlq_name must start with 'ticketing-' and be at most 80 characters."
  }
}

variable "kms_key_arn" {
  description = "Customer managed KMS key for SSE-KMS."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a KMS key ARN."
  }
}

variable "kms_data_key_reuse_period_seconds" {
  description = "Data key reuse period; higher = fewer KMS calls (cost), lower = tighter key usage."
  type        = number
  default     = 300

  validation {
    condition     = var.kms_data_key_reuse_period_seconds >= 60 && var.kms_data_key_reuse_period_seconds <= 86400
    error_message = "kms_data_key_reuse_period_seconds must be between 60 and 86400."
  }
}

variable "visibility_timeout_seconds" {
  description = "ADR-0003: 30 s, greater than the p99 processing time plus internal retries."
  type        = number
  default     = 30

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 0 and 43200."
  }
}

variable "receive_wait_time_seconds" {
  description = "ADR-0003: long polling 20 s."
  type        = number
  default     = 20

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "receive_wait_time_seconds must be between 0 and 20."
  }
}

variable "message_retention_seconds" {
  description = "ADR-0003: 4 days on the main queue."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 and 1209600."
  }
}

variable "dlq_message_retention_seconds" {
  description = "ADR-0003: 14 days on the DLQ (must exceed the main queue retention)."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "dlq_message_retention_seconds must be between 60 and 1209600."
  }
}

variable "max_message_size" {
  description = "Maximum message size in bytes. Messages are thin (orderId + eventId), 64 KiB is plenty."
  type        = number
  default     = 65536

  validation {
    condition     = var.max_message_size >= 1024 && var.max_message_size <= 1048576
    error_message = "max_message_size must be between 1024 and 1048576."
  }
}

variable "max_receive_count" {
  description = "ADR-0003: redrive to the DLQ after 5 receives."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
}

variable "producer_role_arns" {
  description = "IAM role ARNs allowed to SendMessage (producers only)."
  type        = list(string)

  validation {
    condition     = length(var.producer_role_arns) > 0
    error_message = "At least one producer role is required."
  }
}

variable "consumer_role_arns" {
  description = "IAM role ARNs allowed to Receive/Delete/ChangeMessageVisibility (consumers only)."
  type        = list(string)

  validation {
    condition     = length(var.consumer_role_arns) > 0
    error_message = "At least one consumer role is required."
  }
}

variable "break_glass_role_arns" {
  description = "Operator roles exempted from the producer/consumer deny statements (e.g. DLQ redrive, incident response)."
  type        = list(string)
  default     = []
}

variable "source_vpce_ids" {
  description = "SQS interface VPC endpoint IDs the application principals must use. Empty disables the restriction (LocalStack)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
