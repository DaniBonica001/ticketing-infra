data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  # Built from the name so the DLQ can reference its source queue without a dependency cycle.
  main_queue_arn = "arn:${data.aws_partition.current.partition}:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.name}"

  has_vpce_restriction = length(var.source_vpce_ids) > 0
  app_principal_arns   = distinct(concat(var.producer_role_arns, var.consumer_role_arns))

  producer_actions = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
  consumer_actions = [
    "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility",
    "sqs:GetQueueAttributes", "sqs:GetQueueUrl",
  ]
}

resource "aws_sqs_queue" "dlq" {
  name                              = var.dlq_name
  message_retention_seconds         = var.dlq_message_retention_seconds
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  # Only the main queue may move messages into this DLQ. Inline (not a separate
  # aws_sqs_queue_redrive_allow_policy) so deletion does not wait on the attribute being removed.
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [local.main_queue_arn]
  })

  tags = merge(var.tags, { Name = var.dlq_name, Role = "dlq" })
}

resource "aws_sqs_queue" "this" {
  name                              = var.name
  visibility_timeout_seconds        = var.visibility_timeout_seconds
  receive_wait_time_seconds         = var.receive_wait_time_seconds
  message_retention_seconds         = var.message_retention_seconds
  max_message_size                  = var.max_message_size
  kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, { Name = var.name, Role = "main" })
}

data "aws_iam_policy_document" "main" {
  statement {
    sid       = "DenyNonTlsTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.this.arn]

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

  statement {
    sid       = "AllowProducersSend"
    effect    = "Allow"
    actions   = local.producer_actions
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "AWS"
      identifiers = var.producer_role_arns
    }
  }

  statement {
    sid       = "AllowConsumersReceive"
    effect    = "Allow"
    actions   = local.consumer_actions
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "AWS"
      identifiers = var.consumer_role_arns
    }
  }

  # Producer-only SendMessage: any principal that is not a producer (or break-glass admin) is
  # denied, even if an identity policy elsewhere in the account would allow it.
  statement {
    sid       = "DenySendToNonProducers"
    effect    = "Deny"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = concat(var.producer_role_arns, var.break_glass_role_arns)
    }
  }

  # Consumer-only Receive/Delete/ChangeVisibility.
  statement {
    sid       = "DenyConsumeToNonConsumers"
    effect    = "Deny"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility"]
    resources = [aws_sqs_queue.this.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = concat(var.consumer_role_arns, var.break_glass_role_arns)
    }
  }

  # Application principals may only reach the queue through the SQS interface VPC endpoint.
  dynamic "statement" {
    for_each = local.has_vpce_restriction ? [1] : []

    content {
      sid       = "DenyAppPrincipalsOutsideVpce"
      effect    = "Deny"
      actions   = ["sqs:*"]
      resources = [aws_sqs_queue.this.arn]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        variable = "aws:SourceVpce"
        values   = var.source_vpce_ids
      }

      condition {
        test     = "ArnEquals"
        variable = "aws:PrincipalArn"
        values   = local.app_principal_arns
      }
    }
  }
}

resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.main.json
}

data "aws_iam_policy_document" "dlq" {
  statement {
    sid       = "DenyNonTlsTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.dlq.arn]

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

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = data.aws_iam_policy_document.dlq.json
}
