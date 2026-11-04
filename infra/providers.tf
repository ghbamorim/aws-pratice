terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

    datadog = {
      source  = "datadog/datadog"
      version = "~> 3.60"
    }

  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "terraform-lab"
}


provider "datadog" {
  api_url = "https://api.datadoghq.com/"
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}
