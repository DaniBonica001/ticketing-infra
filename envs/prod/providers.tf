provider "aws" {
  region = var.aws_region

  # Guardrail: refuse to plan/apply against any account other than the prod workload account.
  allowed_account_ids = var.allowed_account_ids

  default_tags {
    tags = local.default_tags
  }
}
