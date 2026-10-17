data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

# Key policy model:
# 1. The account root statement delegates authorization to IAM, so each component role gets
#    access to *this* key through its own least-privilege identity policy (scoped with
#    kms:ViaService). This avoids a dependency cycle between keys and roles.
# 2. Key administration is restricted to explicit admin principals (when provided).
# 3. AWS service principals that encrypt on their own behalf (CloudWatch Logs, CloudWatch
#    alarms -> SNS) are added by the caller through `service_policy_json`.
data "aws_iam_policy_document" "this" {
  #checkov:skip=CKV_AWS_111:Key policy: "*" resource means this key only; the root statement is the AWS-recommended IAM delegation.
  #checkov:skip=CKV_AWS_356:Key policy: "*" resource means this key only.
  #checkov:skip=CKV_AWS_109:Key policy: administration is limited to the account (IAM delegation) and explicit admin principals.
  source_policy_documents = var.service_policy_json == null ? [] : [var.service_policy_json]

  statement {
    sid       = "EnableIamPoliciesInThisAccount"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"] # In a key policy, "*" means "this key".

    principals {
      type        = "AWS"
      identifiers = [local.account_root_arn]
    }
  }

  dynamic "statement" {
    for_each = length(var.admin_principal_arns) > 0 ? [1] : []

    content {
      sid    = "AllowKeyAdministration"
      effect = "Allow"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*", "kms:Update*",
        "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*", "kms:TagResource",
        "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion", "kms:RotateKeyOnDemand",
      ]
      resources = ["*"] # In a key policy, "*" means "this key".

      principals {
        type        = "AWS"
        identifiers = var.admin_principal_arns
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  rotation_period_in_days = var.rotation_period_in_days
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region            = false
  policy                  = data.aws_iam_policy_document.this.json

  tags = merge(var.tags, { Name = var.alias })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias}"
  target_key_id = aws_kms_key.this.key_id
}
