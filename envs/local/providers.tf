# Run with `tflocal` (terraform-local): it generates localstack_providers_override.tf that points
# every service endpoint to AWS_ENDPOINT_URL (e.g. http://127.0.0.1:4966) with dummy credentials.
# Never run plain `terraform apply` here with real credentials: allowed_account_ids pins the
# LocalStack account so that mistake fails fast.
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["000000000000"]

  default_tags {
    tags = {
      Project     = "ticketing"
      Environment = "local"
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
      Repository  = "ticketing-infra"
    }
  }
}
