# One CMK per data domain: blast radius and key policies stay small, and access to each key is
# audited separately in CloudTrail.
data "aws_iam_policy_document" "observability_key_services" {
  #checkov:skip=CKV_AWS_111:Key policy statements: "*" resource means this key only, scoped to service principals with conditions.
  #checkov:skip=CKV_AWS_356:Key policy statements: "*" resource means this key only.
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*",
    ]
    resources = ["*"] # In a key policy, "*" means "this key".

    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
    }
  }

  statement {
    sid       = "AllowCloudWatchAlarmsToEncryptedSns"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"] # In a key policy, "*" means "this key".

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

module "kms_data" {
  source = "../../modules/kms"

  alias                = "ticketing-data"
  description          = "Ticketing DynamoDB tables and Lambda environment"
  admin_principal_arns = var.kms_admin_role_arns
}

module "kms_messaging" {
  source = "../../modules/kms"

  alias                = "ticketing-messaging"
  description          = "Ticketing SQS queues"
  admin_principal_arns = var.kms_admin_role_arns
}

module "kms_secrets" {
  source = "../../modules/kms"

  alias                = "ticketing-secrets"
  description          = "Ticketing Secrets Manager secrets"
  admin_principal_arns = var.kms_admin_role_arns
}

module "kms_observability" {
  source = "../../modules/kms"

  alias                = "ticketing-observability"
  description          = "Ticketing CloudWatch log groups and alarm topic"
  admin_principal_arns = var.kms_admin_role_arns
  service_policy_json  = data.aws_iam_policy_document.observability_key_services.json
}
