# =============================================================================
# Package source code into zip
# =============================================================================
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/dist/${var.function_name}.zip"
  excludes    = ["__pycache__", "*.pyc", ".pytest_cache"]
}

# =============================================================================
# IAM Role
# =============================================================================
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Basic CloudWatch Logs permissions
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy attached if provided
resource "aws_iam_role_policy" "custom" {
  count = var.custom_policy_json != null ? 1 : 0

  name   = "${var.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = var.custom_policy_json
}

# =============================================================================
# Lambda Function
# =============================================================================
resource "aws_lambda_function" "this" {
  function_name = "${var.project_name}-${var.function_name}"
  role          = aws_iam_role.lambda.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = var.environment_variables
  }

  tags = {
    Name = "${var.project_name}-${var.function_name}"
  }
}

# =============================================================================
# CloudWatch Log Group (14-day retention)
# =============================================================================
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}
