variable "name" {
  description = "Name prefix (topic, dashboard)."
  type        = string
  default     = "ticketing"
}

variable "sns_kms_key_arn" {
  description = "CMK for the alarm topic (its key policy must allow cloudwatch.amazonaws.com)."
  type        = string
}

variable "alarm_emails" {
  description = "Email endpoints subscribed to the alarm topic (confirmation required)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for e in var.alarm_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "alarm_emails must be valid email addresses."
  }
}

variable "create_alarms" {
  description = "Create the CloudWatch alarms. Only false in LocalStack 4.14, whose CBOR (smithy-rpcv2-cbor) serializer fails on DescribeAlarms as called by the AWS provider 6.x, so Terraform never finishes creating them."
  type        = bool
  default     = true
}

variable "dlq_names" {
  description = "Queues that must always be empty (DLQs and the Lambda failure destination)."
  type        = list(string)
  default     = []
}

variable "queue_max_age_seconds" {
  description = "Main queues => ApproximateAgeOfOldestMessage threshold in seconds."
  type        = map(number)
  default     = {}
}

variable "lambda_function_name" {
  description = "Lambda to alarm on (Errors, Throttles). Null to skip."
  type        = string
  default     = null
}

variable "api" {
  description = "API Gateway REST API to alarm on (null to skip, e.g. LocalStack)."
  type = object({
    name               = string
    stage              = string
    max_5xx_per_minute = optional(number, 5)
    p99_latency_ms     = optional(number, 1000)
  })
  default = null
}

variable "dynamodb_table_names" {
  description = "Tables to alarm on throttling."
  type        = list(string)
  default     = []
}

variable "ecs_cluster_name" {
  description = "ECS cluster for the dashboard."
  type        = string
  default     = null
}

variable "ecs_services" {
  description = "ECS services for the dashboard."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags."
  type        = map(string)
  default     = {}
}
