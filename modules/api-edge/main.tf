data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  use_cognito   = length(var.cognito_user_pool_arns) > 0
  authorization = local.use_cognito ? "COGNITO_USER_POOLS" : "NONE"
  backend_base  = "http://${aws_lb.this.dns_name}:${var.listener_port}"

  # Structured access log (no headers, no query strings, no tokens).
  access_log_format = jsonencode({
    requestId          = "$context.requestId"
    extendedRequestId  = "$context.extendedRequestId"
    ip                 = "$context.identity.sourceIp"
    requestTime        = "$context.requestTime"
    httpMethod         = "$context.httpMethod"
    resourcePath       = "$context.resourcePath"
    status             = "$context.status"
    protocol           = "$context.protocol"
    responseLength     = "$context.responseLength"
    responseLatency    = "$context.responseLatency"
    integrationLatency = "$context.integration.latency"
    integrationStatus  = "$context.integration.status"
    integrationError   = "$context.integration.error"
    wafStatus          = "$context.waf.status"
    xrayTraceId        = "$context.xrayTraceId"
  })
}

resource "aws_api_gateway_vpc_link" "this" {
  name        = "${var.name}-vpc-link"
  description = "API Gateway -> internal NLB -> ms-ticketing-api"
  target_arns = [aws_lb.this.arn]

  tags = var.tags
}

# REST API (not HTTP API) because AWS WAF can only be associated with REST API stages.
resource "aws_api_gateway_rest_api" "this" {
  name        = var.name
  description = "Ticketing public API (regional, WAF-protected)"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = var.name })
}

# Production option: Cognito (or a corporate IdP) authorizer at the edge, in addition to the
# JWT validation the service always performs (defense in depth).
resource "aws_api_gateway_authorizer" "cognito" {
  count = local.use_cognito ? 1 : 0

  name            = "${var.name}-cognito"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = var.cognito_user_pool_arns
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  #checkov:skip=CKV_AWS_59:JWT (RS256, iss/aud/exp) is validated by ms-ticketing-api with Spring Security; set cognito_user_pool_arns to add an edge authorizer in production.
  #checkov:skip=CKV2_AWS_53:Proxy integration; request bodies are validated with Bean Validation in the service (A05).
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = local.authorization
  authorizer_id = local.use_cognito ? aws_api_gateway_authorizer.cognito[0].id : null

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "${local.backend_base}/{proxy}"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.this.id
  timeout_milliseconds    = var.integration_timeout_ms

  # X-Client-Ip is always overwritten with the caller's source IP, so a client-sent value never reaches the
  # service. Behind the NLB the TCP peer is the load balancer; the service trusts this header only from the
  # NLB subnets (TICKETING_RATE_LIMIT_TRUSTED_PROXIES) and uses it as the per-IP rate-limit key.
  request_parameters = {
    "integration.request.path.proxy"         = "method.request.path.proxy"
    "integration.request.header.X-Client-Ip" = "context.identity.sourceIp"
  }
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy.id,
      aws_api_gateway_method.proxy.authorization,
      aws_api_gateway_integration.proxy.id,
      aws_api_gateway_integration.proxy.uri,
      aws_api_gateway_integration.proxy.request_parameters,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}/access"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = var.tags
}

resource "aws_api_gateway_stage" "this" {
  #checkov:skip=CKV_AWS_120:Caching disabled on purpose: availability and order status must be fresh; a cache cluster also adds fixed hourly cost.
  #checkov:skip=CKV2_AWS_77:False positive: the web ACL associated in waf.tf includes AWSManagedRulesKnownBadInputsRuleSet (Log4JRCE); the graph check does not follow the association resource.
  #checkov:skip=CKV2_AWS_51:Backend is private (VPC link to an internal NLB); client certificates protect public HTTP backends.
  rest_api_id          = aws_api_gateway_rest_api.this.id
  deployment_id        = aws_api_gateway_deployment.this.id
  stage_name           = var.stage_name
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format          = local.access_log_format
  }

  tags = merge(var.tags, { Name = "${var.name}-${var.stage_name}" })

  depends_on = [aws_api_gateway_account.this]
}

resource "aws_api_gateway_method_settings" "all" {
  #checkov:skip=CKV_AWS_225:Caching disabled on purpose (fresh availability/order status, no fixed cache-cluster cost).
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "ERROR"
    data_trace_enabled     = false # Never log full request/response bodies.
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
    caching_enabled        = false
  }
}

# --------------------------------------------------------------------------------------------
# Account-level CloudWatch role for API Gateway execution logs. It is a per-region account
# singleton: manage it here only if no other stack in the account does.
# --------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "apigw_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "apigw_cloudwatch" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  name               = "${var.name}-apigw-cloudwatch"
  path               = "/ticketing/"
  assume_role_policy = data.aws_iam_policy_document.apigw_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  role       = aws_iam_role.apigw_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  count = var.manage_account_cloudwatch_role ? 1 : 0

  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch[0].arn

  depends_on = [aws_iam_role_policy_attachment.apigw_cloudwatch]
}
