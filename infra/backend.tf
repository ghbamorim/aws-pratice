terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "aws-pratice-tfstate-280bb6556d35eca69b1d402713"
    key          = "infra/terraform.tfstate"
    region       = "us-east-2"
    profile      = "terraform-lab"
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