# --------------------------------------------------------------------------------------------
# VPC endpoints. Gateway endpoints are free; interface endpoints are billed per AZ-hour and GB.
# Endpoint policies restrict *who* (principals of this account) and, where the service supports
# it, *what* (resources of this account / of this project).
# --------------------------------------------------------------------------------------------
locals {
  route_table_ids = [for rt in aws_route_table.private : rt.id]

  # Services whose every action targets an account-owned resource: aws:ResourceAccount applies.
  resource_scoped_services = ["sqs", "secretsmanager", "kms", "logs"]
}

data "aws_iam_policy_document" "dynamodb_endpoint" {
  statement {
    sid       = "ProjectTablesOnly"
    effect    = "Allow"
    actions   = ["dynamodb:*"]
    resources = ["arn:aws:dynamodb:${local.region}:${local.account_id}:table/${var.dynamodb_table_prefix}*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.route_table_ids
  policy            = data.aws_iam_policy_document.dynamodb_endpoint.json

  tags = merge(var.tags, { Name = "${var.name}-dynamodb" })
}

# ECR stores image layers in an AWS-owned S3 bucket; this is the only S3 access allowed.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "EcrLayersOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::prod-${local.region}-starport-layer-bucket/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.route_table_ids
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = merge(var.tags, { Name = "${var.name}-s3-ecr-layers" })
}

data "aws_iam_policy_document" "interface_endpoint" {
  for_each = local.interface_endpoints

  statement {
    sid       = "ThisAccountOnly"
    effect    = "Allow"
    actions   = ["${split(".", each.value)[0]}:*"] # Only the endpoint's own service (ecr.api/ecr.dkr -> ecr:*).
    resources = ["*"]                              # Narrowed by the conditions below; endpoint policies cannot list every future ARN.

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [local.account_id]
    }

    dynamic "condition" {
      for_each = contains(local.resource_scoped_services, each.value) ? [1] : []

      content {
        test     = "StringEquals"
        variable = "aws:ResourceAccount"
        values   = [local.account_id]
      }
    }
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${local.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  policy              = data.aws_iam_policy_document.interface_endpoint[each.value].json

  tags = merge(var.tags, { Name = "${var.name}-${replace(each.value, ".", "-")}" })
}
