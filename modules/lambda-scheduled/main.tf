locals {
  failures_queue_name = "${var.function_name}-failures"
  alias_name          = "live"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = var.tags
}

# Async failure destination. Lambda delivers here (with the full invocation context) after the
# async retries are exhausted. It is NOT behind the VPC endpoint restriction because the Lambda
# service itself (not the function code) sends the record.
resource "aws_sqs_queue" "failures" {
  name                      = local.failures_queue_name
  message_retention_seconds = 1209600
  kms_master_key_id         = var.messaging_kms_key_arn

  tags = merge(var.tags, { Name = local.failures_queue_name, Role = "lambda-failure-destination" })
}

data "aws_iam_policy_document" "failures" {
  statement {
    sid       = "DenyNonTlsTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.failures.arn]

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

resource "aws_sqs_queue_policy" "failures" {
  queue_url = aws_sqs_queue.failures.id
  policy    = data.aws_iam_policy_document.failures.json
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_116:Async failures go to an on-failure *destination* (aws_lambda_function_event_invoke_config), which supersedes the legacy DLQ and carries the invocation context.
  #checkov:skip=CKV_AWS_272:Code signing requires an AWS Signer profile owned by the CI pipeline; the artifact integrity is enforced by source_code_hash and the CI provenance. Documented as a production improvement.
  function_name                  = var.function_name
  description                    = var.description
  role                           = var.role_arn
  runtime                        = var.runtime
  handler                        = var.handler
  architectures                  = [var.architecture]
  filename                       = var.package_path
  source_code_hash               = filebase64sha256(var.package_path)
  memory_size                    = var.memory_size
  timeout                        = var.timeout_seconds
  reserved_concurrent_executions = var.reserved_concurrency
  publish                        = true
  kms_key_arn                    = var.environment_kms_key_arn

  environment {
    variables = var.environment
  }

  logging_config {
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.this.name
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  tracing_config {
    mode = var.tracing_mode
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []

    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  # SnapStart restores a snapshot of the initialized JVM to cut Java cold starts. It only applies
  # to *published versions*, which is why the schedule invokes the `live` alias. Support for the
  # java25 managed runtime must be confirmed in the AWS docs ("Lambda SnapStart supported
  # runtimes") for the target region before enabling it; it is a variable for that reason and it
  # is disabled in LocalStack, which does not emulate snapshots.
  dynamic "snap_start" {
    for_each = var.snapstart_enabled ? [1] : []

    content {
      apply_on = "PublishedVersions"
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = merge(var.tags, { Name = var.function_name })
}

resource "aws_lambda_alias" "live" {
  name             = local.alias_name
  description      = "Version invoked by the EventBridge schedule."
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

resource "aws_lambda_function_event_invoke_config" "this" {
  function_name = aws_lambda_function.this.function_name
  qualifier     = aws_lambda_alias.live.name

  # The next tick (1 minute later) is the natural retry; overlapping retries only add contention.
  maximum_retry_attempts       = var.async_retry_attempts
  maximum_event_age_in_seconds = var.async_max_event_age_seconds

  destination_config {
    on_failure {
      destination = aws_sqs_queue.failures.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = var.schedule_name
  description         = "Triggers ${var.function_name} (${var.schedule_expression})."
  schedule_expression = var.schedule_expression
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"

  tags = merge(var.tags, { Name = var.schedule_name })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "${var.function_name}-live"
  arn       = aws_lambda_alias.live.arn

  retry_policy {
    maximum_retry_attempts       = 2
    maximum_event_age_in_seconds = 120
  }
}

resource "aws_lambda_permission" "events" {
  statement_id  = "AllowEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
