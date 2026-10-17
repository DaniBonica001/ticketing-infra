# ============================================================================================
# Pure policy module (no resources): the least-privilege identity policies of each component,
# shared by envs/local and envs/prod so both environments grant exactly the same permissions.
# Resources are always ARNs; the only "*" resources are the ones AWS requires (commented).
# Note: TransactWriteItems is authorized per item action (PutItem/UpdateItem/ConditionCheckItem),
# so the audit row written inside each transaction needs dynamodb:PutItem on the audit table.
# The audit table is append-only: no role gets UpdateItem/DeleteItem on it.
# ============================================================================================
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.region
  # Mutable tables. The audit table is granted separately (append-only).
  table_arns = [var.events_table_arn, var.orders_table_arn]
  queue_arns = [var.orders_queue_arn, var.confirmations_queue_arn]

  dynamodb_write_actions = [
    "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:ConditionCheckItem",
  ]
  audit_append_actions = ["dynamodb:PutItem"]
  sqs_produce_actions  = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
  sqs_consume_actions = [
    "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility",
    "sqs:GetQueueAttributes", "sqs:GetQueueUrl",
  ]
}

# KMS only through DynamoDB and SQS (kms:ViaService): the roles cannot use the keys directly.
data "aws_iam_policy_document" "kms_via_dynamodb" {
  statement {
    sid       = "DataKeyViaDynamoDb"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = [var.data_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${local.region}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "kms_via_sqs" {
  statement {
    sid       = "MessagingKeyViaSqs"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [var.messaging_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sqs.${local.region}.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------------------------
# ms-ticketing-api: DynamoDB on events/orders + GSI, append + history Query on audit,
# SendMessage on both queues.
# --------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "api" {
  source_policy_documents = [
    data.aws_iam_policy_document.kms_via_dynamodb.json,
    data.aws_iam_policy_document.kms_via_sqs.json,
  ]

  statement {
    sid       = "TablesReadWrite"
    actions   = concat(local.dynamodb_write_actions, ["dynamodb:Query"])
    resources = concat(local.table_arns, [var.orders_gsi_arn])
  }

  # T1/T8 audit rows (TransactWriteItems Put) and GET /orders/{id}/history (Query by orderId).
  statement {
    sid       = "AuditAppendAndHistory"
    actions   = concat(local.audit_append_actions, ["dynamodb:Query"])
    resources = [var.audit_table_arn]
  }

  statement {
    sid       = "ListEvents"
    actions   = ["dynamodb:Scan"]
    resources = [var.events_table_arn]
  }

  statement {
    sid       = "ProduceToQueues"
    actions   = local.sqs_produce_actions
    resources = local.queue_arns
  }
}

# --------------------------------------------------------------------------------------------
# ms-order-processor: DynamoDB, consume both queues, read its secret.
# --------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "processor" {
  source_policy_documents = [
    data.aws_iam_policy_document.kms_via_dynamodb.json,
    data.aws_iam_policy_document.kms_via_sqs.json,
  ]

  statement {
    sid       = "TablesReadWrite"
    actions   = concat(local.dynamodb_write_actions, ["dynamodb:Query"])
    resources = local.table_arns
  }

  # T2/T3/T5/T6 audit rows (TransactWriteItems Put).
  statement {
    sid       = "AuditAppend"
    actions   = local.audit_append_actions
    resources = [var.audit_table_arn]
  }

  statement {
    sid       = "ConsumeQueues"
    actions   = local.sqs_consume_actions
    resources = local.queue_arns
  }

  statement {
    sid       = "ReadPaymentGatewaySecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.payment_gateway_secret_arn]
  }

  statement {
    sid       = "SecretsKeyViaSecretsManager"
    actions   = ["kms:Decrypt"]
    resources = [var.secrets_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${local.region}.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------------------------
# ticketing-reservation-expirer (Lambda): GSI query, T7 writes, reconciliation sends.
# --------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "expirer_vpc" {
  #checkov:skip=CKV_AWS_111:Lambda VPC ENI management requires Resource "*" (same as the AWSLambdaVPCAccessExecutionRole managed policy).
  #checkov:skip=CKV_AWS_356:Lambda VPC ENI management requires Resource "*".
  statement {
    sid = "VpcNetworkInterfaces"
    actions = [
      "ec2:CreateNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface",
      "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"] # Lambda manages ENIs whose IDs are unknown in advance; ec2:Describe* has no resource-level permissions.
  }
}

data "aws_iam_policy_document" "expirer" {
  source_policy_documents = concat(
    [
      data.aws_iam_policy_document.kms_via_dynamodb.json,
      data.aws_iam_policy_document.kms_via_sqs.json,
    ],
    var.expirer_vpc_attached ? [data.aws_iam_policy_document.expirer_vpc.json] : [],
  )

  statement {
    sid       = "QueryLiveOrders"
    actions   = ["dynamodb:Query"]
    resources = [var.orders_table_arn, var.orders_gsi_arn]
  }

  statement {
    sid       = "TablesWrite"
    actions   = local.dynamodb_write_actions
    resources = local.table_arns
  }

  # T7 audit rows (TransactWriteItems Put).
  statement {
    sid       = "AuditAppend"
    actions   = local.audit_append_actions
    resources = [var.audit_table_arn]
  }

  statement {
    sid       = "ReconciliationAndFailureDestination"
    actions   = local.sqs_produce_actions
    resources = concat(local.queue_arns, [var.expirer_failures_queue_arn])
  }

  # Lambda decrypts the CMK-encrypted environment variables with the execution role.
  statement {
    sid       = "DecryptEnvironment"
    actions   = ["kms:Decrypt"]
    resources = [var.data_kms_key_arn]
  }

  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${var.expirer_log_group_arn}:*"]
  }

  statement {
    sid       = "XRayTraces"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"] # X-Ray does not support resource-level permissions for these actions.
  }
}
