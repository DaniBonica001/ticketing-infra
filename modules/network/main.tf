data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
  azs        = slice(var.availability_zones, 0, var.az_count)

  # /20 per private subnet (4 091 usable IPs): Fargate tasks and Lambda ENIs each take one IP.
  private_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 4, index)
  }

  interface_endpoints = toset(var.interface_endpoint_services)
}

# --------------------------------------------------------------------------------------------
# VPC: private subnets only. No Internet Gateway, no NAT: workloads have no route to the
# internet and reach AWS APIs exclusively through VPC endpoints.
# --------------------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # Required for interface endpoint private DNS.

  tags = merge(var.tags, { Name = var.name })
}

# Lock down the default SG (CKV2_AWS_12): nothing may use it implicitly.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-default-deny" })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}", Tier = "private" })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-private-${each.key}" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# --------------------------------------------------------------------------------------------
# Flow logs (ALL traffic) to an encrypted log group.
# --------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = var.tags
}

data "aws_iam_policy_document" "flow_logs_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-flow-logs"
  path               = "/ticketing/"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.name}-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_flow_log" "this" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}
