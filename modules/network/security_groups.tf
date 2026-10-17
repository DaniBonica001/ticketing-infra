# --------------------------------------------------------------------------------------------
# Least-privilege security groups. Rules are separate resources so SGs can reference each other
# without cycles. A Terraform-managed aws_security_group has NO default egress rule.
#
#   NLB  --8080/9090-->  API
#   API / processor / Lambda  --443-->  interface endpoints SG
#   API / processor / Lambda  --443-->  DynamoDB + S3 gateway endpoints (AWS prefix lists)
#   processor  --443-->  payment gateway CIDRs (PrivateLink / egress VPC; empty by default)
# --------------------------------------------------------------------------------------------
resource "aws_security_group" "endpoints" {
  name        = "${var.name}-vpc-endpoints"
  description = "Interface VPC endpoints: HTTPS only from application SGs"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-vpc-endpoints" })
}

resource "aws_security_group" "nlb" {
  #checkov:skip=CKV2_AWS_5:Attached to the NLB in modules/api-edge (cross-module reference not resolved by the scanner).
  name        = "${var.name}-nlb"
  description = "Internal NLB behind the API Gateway VPC link"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-nlb" })
}

resource "aws_security_group" "app" {
  #checkov:skip=CKV2_AWS_5:Attached to the ECS services and the Lambda in other modules (cross-module reference not resolved by the scanner).
  for_each = toset(["api", "processor", "lambda"])

  name        = "${var.name}-${each.key}"
  description = "Ticketing ${each.key} workload"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

# Endpoints: 443 in from each application SG.
resource "aws_vpc_security_group_ingress_rule" "endpoints_from_app" {
  for_each = aws_security_group.app

  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from ${each.key}"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = each.value.id
}

# NLB -> API (application and actuator health-check ports).
resource "aws_vpc_security_group_egress_rule" "nlb_to_api" {
  for_each = toset([tostring(var.api_port), tostring(var.api_health_port)])

  security_group_id            = aws_security_group.nlb.id
  description                  = "NLB to API port ${each.value}"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.app["api"].id
}

resource "aws_vpc_security_group_ingress_rule" "api_from_nlb" {
  for_each = toset([tostring(var.api_port), tostring(var.api_health_port)])

  security_group_id            = aws_security_group.app["api"].id
  description                  = "API port ${each.value} from the NLB"
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.value)
  to_port                      = tonumber(each.value)
  referenced_security_group_id = aws_security_group.nlb.id
}

# App -> interface endpoints.
resource "aws_vpc_security_group_egress_rule" "app_to_endpoints" {
  for_each = aws_security_group.app

  security_group_id            = each.value.id
  description                  = "HTTPS to interface VPC endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoints.id
}

# App -> gateway endpoints (DynamoDB, S3 for ECR layers) through their managed prefix lists.
resource "aws_vpc_security_group_egress_rule" "app_to_gateway_endpoints" {
  for_each = {
    for pair in setproduct(keys(aws_security_group.app), ["dynamodb", "s3"]) : "${pair[0]}-${pair[1]}" => {
      sg      = pair[0]
      service = pair[1]
    }
  }

  security_group_id = aws_security_group.app[each.value.sg].id
  description       = "HTTPS to the ${each.value.service} gateway endpoint"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = each.value.service == "dynamodb" ? aws_vpc_endpoint.dynamodb.prefix_list_id : aws_vpc_endpoint.s3.prefix_list_id
}

# Processor -> payment gateway (only if CIDRs are provided; see README "Egress").
resource "aws_vpc_security_group_egress_rule" "processor_to_payment_gateway" {
  for_each = toset(var.payment_gateway_cidrs)

  security_group_id = aws_security_group.app["processor"].id
  description       = "HTTPS to the payment gateway (PrivateLink or egress VPC)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}
