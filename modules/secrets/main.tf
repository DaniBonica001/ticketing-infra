# The secret container only. The value ({"apiKey": "..."}) is set out-of-band
# (`aws secretsmanager put-secret-value`) so it never lands in code, plans or state.
resource "aws_secretsmanager_secret" "this" {
  #checkov:skip=CKV2_AWS_57:The payment gateway API key is issued by a third party; rotation is a manual, out-of-band procedure documented in the README (no rotation Lambda can call the provider).
  name                    = var.name
  description             = var.description
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  tags = merge(var.tags, { Name = var.name })
}

data "aws_iam_policy_document" "this" {
  statement {
    sid       = "DenyReadToNonReaders"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"] # In a resource policy, "*" means "this secret".

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = var.reader_role_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.source_vpce_ids) > 0 ? [1] : []

    content {
      sid       = "DenyReadersOutsideVpce"
      effect    = "Deny"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = ["*"] # In a resource policy, "*" means "this secret".

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
        values   = var.reader_role_arns
      }
    }
  }
}

resource "aws_secretsmanager_secret_policy" "this" {
  secret_arn          = aws_secretsmanager_secret.this.arn
  policy              = data.aws_iam_policy_document.this.json
  block_public_policy = true
}
