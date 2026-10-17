variable "events_table_arn" {
  description = "ticketing-events table ARN."
  type        = string
}

variable "orders_table_arn" {
  description = "ticketing-orders table ARN."
  type        = string
}

variable "audit_table_arn" {
  description = "ticketing-order-audit table ARN."
  type        = string
}

variable "orders_gsi_arn" {
  description = "status-deadlineAt-index ARN."
  type        = string

  validation {
    condition     = can(regex("/index/status-deadlineAt-index$", var.orders_gsi_arn))
    error_message = "orders_gsi_arn must be the status-deadlineAt-index ARN."
  }
}

variable "orders_queue_arn" {
  description = "ticketing-orders-queue ARN."
  type        = string
}

variable "confirmations_queue_arn" {
  description = "ticketing-confirmations-queue ARN."
  type        = string
}

variable "payment_gateway_secret_arn" {
  description = "ticketing/payment-gateway secret ARN."
  type        = string
}

variable "data_kms_key_arn" {
  description = "CMK of the DynamoDB tables and Lambda environment."
  type        = string
}

variable "messaging_kms_key_arn" {
  description = "CMK of the SQS queues."
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "CMK of the secrets."
  type        = string
}

variable "expirer_failures_queue_arn" {
  description = "Lambda on-failure destination queue ARN."
  type        = string
}

variable "expirer_log_group_arn" {
  description = "Lambda log group ARN."
  type        = string
}

variable "expirer_vpc_attached" {
  description = "Whether the expirer runs in a VPC (adds the ENI management statement)."
  type        = bool
  default     = true
}
