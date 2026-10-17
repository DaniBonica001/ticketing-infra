module "edge" {
  source = "../../modules/api-edge"

  name                        = "ticketing-api"
  stage_name                  = "v1"
  vpc_id                      = module.network.vpc_id
  subnet_ids                  = module.network.private_subnet_ids
  nlb_security_group_id       = module.network.security_group_ids["nlb"]
  api_port                    = local.api_port
  api_health_port             = local.management_port
  throttling_rate_limit       = var.api_throttling.rate_limit
  throttling_burst_limit      = var.api_throttling.burst_limit
  waf_rate_limit_per_5min     = var.api_throttling.waf_per_ip_per_5_min
  cognito_user_pool_arns      = var.cognito_user_pool_arns
  deletion_protection_enabled = var.deletion_protection_enabled
  logs_kms_key_arn            = module.kms_observability.key_arn
}
