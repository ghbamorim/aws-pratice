terraform {
  backend "s3" {
    bucket       = "aws-pratice-tfstate-280bb6556d35eca69b1d402713"
    key          = "infra/terraform.tfstate"
    region       = "us-east-2"
    profile      = "terraform-lab"
    use_lockfile = true
  }
}