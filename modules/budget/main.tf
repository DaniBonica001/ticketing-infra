resource "aws_budgets_budget" "monthly" {
  name         = var.name
  budget_type  = "COST"
  limit_amount = format("%.2f", var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Requires "Project" to be activated as a cost allocation tag in the billing console.
  dynamic "cost_filter" {
    for_each = var.filter_by_project_tag ? [1] : []

    content {
      name   = "TagKeyValue"
      values = ["user:Project$${var.project_tag_value}"]
    }
  }

  dynamic "notification" {
    for_each = var.notifications

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold_percent
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = var.subscriber_emails
    }
  }

  tags = var.tags
}
