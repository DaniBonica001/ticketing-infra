data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  region        = data.aws_region.current.region
  alarm_actions = [aws_sns_topic.alarms.arn]
  has_api       = var.api != null
  has_lambda    = var.lambda_function_name != null
}

# --------------------------------------------------------------------------------------------
# Alarm topic (CMK-encrypted). CloudWatch needs kms:GenerateDataKey/Decrypt on the key, granted
# in the key policy by the caller (see envs/*/kms.tf).
# --------------------------------------------------------------------------------------------
resource "aws_sns_topic" "alarms" {
  name              = "${var.name}-alarms"
  kms_master_key_id = var.sns_kms_key_arn

  tags = merge(var.tags, { Name = "${var.name}-alarms" })
}

data "aws_iam_policy_document" "alarms_topic" {
  statement {
    sid       = "AllowCloudWatchAlarms"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyNonTlsTransport"
    effect    = "Deny"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alarms.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "alarms" {
  arn    = aws_sns_topic.alarms.arn
  policy = data.aws_iam_policy_document.alarms_topic.json
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alarm_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

# --------------------------------------------------------------------------------------------
# SQS: any message in a DLQ is an incident (poison message or exhausted retries).
# --------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  for_each = var.create_alarms ? toset(var.dlq_names) : toset([])

  alarm_name          = "${each.value}-not-empty"
  alarm_description   = "Messages landed in ${each.value}. Inspect, fix and redrive."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = each.value }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  for_each = var.create_alarms ? var.queue_max_age_seconds : {}

  alarm_name          = "${each.key}-oldest-message-age"
  alarm_description   = "Oldest message in ${each.key} is older than ${each.value}s: consumers are not keeping up."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = each.key }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  tags = var.tags
}

# --------------------------------------------------------------------------------------------
# Lambda (reservation expirer): errors and throttles mean inventory is not being released.
# --------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda" {
  for_each = var.create_alarms && local.has_lambda ? toset(["Errors", "Throttles"]) : toset([])

  alarm_name          = "${var.lambda_function_name}-${lower(each.value)}"
  alarm_description   = "${var.lambda_function_name} ${each.value} > 0 for 3 consecutive minutes: expired reservations are not returning to inventory."
  namespace           = "AWS/Lambda"
  metric_name         = each.value
  dimensions          = { FunctionName = var.lambda_function_name }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  tags = var.tags
}

# --------------------------------------------------------------------------------------------
# API Gateway: 5xx and p99 latency.
# --------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  count = var.create_alarms && local.has_api ? 1 : 0

  alarm_name          = "${var.api.name}-5xx"
  alarm_description   = "API Gateway 5XX errors above ${var.api.max_5xx_per_minute}/min."
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions          = { ApiName = var.api.name, Stage = var.api.stage }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.api.max_5xx_per_minute
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "api_latency_p99" {
  count = var.create_alarms && local.has_api ? 1 : 0

  alarm_name          = "${var.api.name}-latency-p99"
  alarm_description   = "API Gateway p99 latency above ${var.api.p99_latency_ms} ms."
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  dimensions          = { ApiName = var.api.name, Stage = var.api.stage }
  extended_statistic  = "p99"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.api.p99_latency_ms
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  tags = var.tags
}

# --------------------------------------------------------------------------------------------
# DynamoDB: read + write throttle events per table (hot item / hot partition signal).
# --------------------------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = var.create_alarms ? toset(var.dynamodb_table_names) : toset([])

  alarm_name          = "${each.value}-throttles"
  alarm_description   = "Throttled requests on ${each.value} (hot item/partition, see dynamodb.md section 5)."
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "throttles"
    expression  = "reads + writes"
    label       = "Throttle events"
    return_data = true
  }

  metric_query {
    id = "reads"

    metric {
      namespace   = "AWS/DynamoDB"
      metric_name = "ReadThrottleEvents"
      dimensions  = { TableName = each.value }
      stat        = "Sum"
      period      = 60
    }
  }

  metric_query {
    id = "writes"

    metric {
      namespace   = "AWS/DynamoDB"
      metric_name = "WriteThrottleEvents"
      dimensions  = { TableName = each.value }
      stat        = "Sum"
      period      = 60
    }
  }

  tags = var.tags
}
