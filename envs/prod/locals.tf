data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  default_tags = {
    Project     = "ticketing"
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
    Repository  = "ticketing-infra"
  }

  # Names are binding: docs/design/conventions.md (application repo).
  names = {
    events_table           = "ticketing-events"
    orders_table           = "ticketing-orders"
    audit_table            = "ticketing-order-audit"
    orders_gsi             = "status-deadlineAt-index"
    orders_queue           = "ticketing-orders-queue"
    orders_dlq             = "ticketing-orders-dlq"
    confirmations_queue    = "ticketing-confirmations-queue"
    confirmations_dlq      = "ticketing-confirmations-dlq"
    payment_gateway_secret = "ticketing/payment-gateway"
    expirer_function       = "ticketing-reservation-expirer"
    expirer_schedule       = "ticketing-reservation-expirer-schedule"
    api_service            = "ms-ticketing-api"
    processor_service      = "ms-order-processor"
    cluster                = "ticketing-cluster"
  }

  api_port        = 8080
  management_port = 9090
}
