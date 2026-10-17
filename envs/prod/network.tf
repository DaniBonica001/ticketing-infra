module "network" {
  source = "../../modules/network"

  name                  = "ticketing-${var.environment}"
  vpc_cidr              = var.vpc_cidr
  az_count              = var.az_count
  api_port              = local.api_port
  api_health_port       = local.management_port
  payment_gateway_cidrs = var.payment_gateway_cidrs
  logs_kms_key_arn      = module.kms_observability.key_arn
}
