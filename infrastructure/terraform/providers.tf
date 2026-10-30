
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "ghostfolio-terraform-state-sy7-2026"
    key          = "ghostfolio/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
