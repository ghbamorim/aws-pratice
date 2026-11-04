data "aws_caller_identity" "current" {}

resource "aws_secretsmanager_secret" "datadog_api_key" {
  name_prefix = "aws-pratice-datadog-api-key-"
  description = "Datadog API key read by the EC2 Agent at boot"

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = var.datadog_api_key
}

resource "datadog_integration_aws_external_id" "lab" {}

resource "aws_iam_role" "datadog" {
  name = "aws-pratice-datadog-integration"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"

      Principal = {
        AWS = "arn:aws:iam::464622532012:root"
      }

      Condition = {
        StringEquals = {
          "sts:ExternalId" = datadog_integration_aws_external_id.lab.id
        }
      }
    }]
  })

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}


# Read-only discovery and CloudWatch metrics permissions.
resource "aws_iam_role_policy" "datadog_metrics" {
  name = "aws-pratice-datadog-metrics"
  role = aws_iam_role.datadog.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Action = [
        "cloudwatch:DescribeAlarms",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumeStatus",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTags",
        "elasticloadbalancing:DescribeTargetGroups",
        "lambda:GetPolicy",
        "lambda:ListFunctions",
        "lambda:ListTags",
        "rds:DescribeDBClusters",
        "rds:DescribeDBInstances",
        "rds:DescribeEvents",
        "rds:ListTagsForResource",
        "s3:GetBucketLocation",
        "s3:GetBucketTagging",
        "s3:ListAllMyBuckets",
        "tag:GetResources",
        "tag:GetTagKeys",
        "tag:GetTagValues"
      ]

      Resource = "*"
    }]
  })
}


# Connect the AWS account to Datadog.
resource "datadog_integration_aws_account" "lab" {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_partition  = "aws"

  account_tags = [
    "env:lab",
    "project:aws-pratice"
  ]

  # Monitor resources only in the Ohio region.
  aws_regions {
    include_only = ["us-east-2"]
  }

  # Authenticate using the IAM role and external ID.
  auth_config {
    aws_auth_config_role {
      role_name   = aws_iam_role.datadog.name
      external_id = datadog_integration_aws_external_id.lab.id
    }
  }

  # Collect AWS metrics through CloudWatch.
  metrics_config {
    enabled                   = true
    automute_enabled          = true
    collect_cloudwatch_alarms = false
    collect_custom_metrics    = false

    namespace_filters {
      include_only = [
        "AWS/EC2",
        "AWS/EBS",
        "AWS/RDS",
        "AWS/Lambda",
        "AWS/ELB",
        "AWS/ApplicationELB",
        "AWS/NetworkELB",
        "AWS/S3"
      ]
    }
  }

  # Disable additional resource discovery features.
  resources_config {
    cloud_security_posture_management_collection = false
    extended_collection                          = false
  }

  # Log forwarding will be configured separately.
  logs_config {
    lambda_forwarder {}
  }

  # X-Ray integration will be configured separately.
  traces_config {
    xray_services {
      include_only = []
    }
  }

  depends_on = [
    aws_iam_role_policy.datadog_metrics
  ]
}
