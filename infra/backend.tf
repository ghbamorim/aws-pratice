terraform {
  backend "s3" {
    bucket       = "aws-pratice-terraform-state-242627333067-us-east-2"
    key          = "infra/terraform.tfstate"
    region       = "us-east-2"
    profile      = "terraform-lab"
    use_lockfile = true
  }
}