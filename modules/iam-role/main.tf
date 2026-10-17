data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowServiceAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = var.trusted_services
    }

    # Confused-deputy protection: only this account's resources can make the service assume
    # the role (supported by ecs-tasks.amazonaws.com; see variable description).
    dynamic "condition" {
      for_each = var.restrict_to_source_account ? [1] : []

      content {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.name
  description          = var.description
  path                 = var.path
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-least-privilege"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
