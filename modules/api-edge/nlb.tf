# --------------------------------------------------------------------------------------------
# Internal NLB: the only target of the API Gateway VPC link. REST API VPC links (v1) require an
# NLB; it lives in the private subnets and is not reachable from the internet.
# --------------------------------------------------------------------------------------------
resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:NLB access logs are only produced for TLS listeners; request-level logs are API Gateway access logs and WAF logs, connection-level data is in VPC flow logs.
  #checkov:skip=CKV2_AWS_20:Not an ALB; HTTP->HTTPS redirect does not apply. TLS terminates at API Gateway and traffic to the NLB travels over PrivateLink inside AWS.
  #checkov:skip=CKV2_AWS_28:WAF is attached to the API Gateway stage (the public entry point); WAF cannot be associated with an NLB.
  name                             = "${var.name}-nlb"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  security_groups                  = [var.nlb_security_group_id]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.deletion_protection_enabled

  # VPC link traffic arrives through PrivateLink; inbound SG evaluation for it is turned off so the
  # NLB SG can stay with zero ingress rules (nothing else in the VPC can reach the listener).
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"

  tags = merge(var.tags, { Name = "${var.name}-nlb" })
}

resource "aws_lb_target_group" "api" {
  name                 = "${var.name}-api"
  port                 = var.api_port
  protocol             = "TCP"
  target_type          = "ip" # Fargate awsvpc tasks register by IP.
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = tostring(var.api_health_port)
    path                = var.api_health_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = merge(var.tags, { Name = "${var.name}-api" })
}

resource "aws_lb_listener" "api" {
  #checkov:skip=CKV_AWS_2:TCP listener reachable only through the VPC link (PrivateLink); TLS is terminated at API Gateway. An ACM-backed TLS listener is the documented upgrade path.
  #checkov:skip=CKV_AWS_103:Same as above, no TLS listener on the private hop.
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  tags = var.tags
}
