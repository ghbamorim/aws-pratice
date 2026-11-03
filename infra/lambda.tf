# Package the Lambda handler
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../lambda/handler.py"
  output_path = "${path.module}/lambda.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda" {
  name = "aws-pratice-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Allow Lambda to write CloudWatch logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch log group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/aws-pratice-lambda"
  retention_in_days = 7

  tags = {
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Lambda function for observability testing
resource "aws_lambda_function" "processor" {
  function_name = "aws-pratice-lambda"

  role    = aws_iam_role.lambda.arn
  runtime = "python3.12"
  handler = "handler.handler"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  memory_size = 128
  timeout     = 3

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda
  ]

  tags = {
    Name      = "aws-pratice-lambda"
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Lambda function ARN
output "lambda_arn" {
  value = aws_lambda_function.processor.arn
}

# Lambda function name
output "lambda_name" {
  value = aws_lambda_function.processor.function_name
}
