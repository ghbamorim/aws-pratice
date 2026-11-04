# Terraform needs both keys; the EC2 Agent receives only the API key.
variable "datadog_api_key" {
  description = "Datadog US1 API key, supplied with TF_VAR_datadog_api_key"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key with AWS integration management permissions, supplied with TF_VAR_datadog_app_key"
  type        = string
  sensitive   = true
}
