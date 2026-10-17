terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration: bucket/key/region come from backend.hcl (see backend.hcl.example),
  # one state per environment and per account. Native S3 locking (no DynamoDB lock table).
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
