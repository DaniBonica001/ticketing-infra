terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Local state on purpose: LocalStack is ephemeral and this state is never shared.
  backend "local" {
    path = "terraform.tfstate"
  }
}
