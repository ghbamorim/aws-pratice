variable "project_name" {
  description = "Name used to identify project resources"
  type        = string
  default     = "aws-pratice"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "lab"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}