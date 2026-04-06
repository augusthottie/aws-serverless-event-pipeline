terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}

# =============================================================================
# Shared code — each Lambda includes its own copy of shared/
# We copy shared/ into each function's source dir before packaging
# =============================================================================
resource "null_resource" "bundle_shared" {
  provisioner "local-exec" {
    command = <<-EOT
      for fn in shortener redirect analytics stats; do
        rm -rf ../src/$fn/shared
        cp -r ../src/shared ../src/$fn/shared
      done
    EOT
  }

  triggers = {
    # Re-run when any source file changes
    shared_hash = filemd5("../src/shared/utils.py")
  }
}

# =============================================================================
# DynamoDB Tables
# =============================================================================
module "dynamodb" {
  source       = "./modules/dynamodb"
  project_name = var.project_name
}

# =============================================================================
# SQS Queue + DLQ
# =============================================================================
module "sqs" {
  source       = "./modules/sqs"
  project_name = var.project_name
}

# =============================================================================
# Lambda: Shortener
# Needs: DynamoDB write to urls table
# =============================================================================
module "lambda_shortener" {
  source        = "./modules/lambda"
  project_name  = var.project_name
  function_name = "shortener"
  source_dir    = "../src/shortener"

  environment_variables = {
    URLS_TABLE = module.dynamodb.urls_table_name
    BASE_URL   = var.base_url
  }

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
      ]
      Resource = module.dynamodb.urls_table_arn
    }]
  })

  depends_on = [null_resource.bundle_shared]
}

# =============================================================================
# Lambda: Redirect
# Needs: DynamoDB read from urls table, SQS send
# =============================================================================
module "lambda_redirect" {
  source        = "./modules/lambda"
  project_name  = var.project_name
  function_name = "redirect"
  source_dir    = "../src/redirect"

  environment_variables = {
    URLS_TABLE        = module.dynamodb.urls_table_name
    CLICKS_QUEUE_URL  = module.sqs.queue_url
  }

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem"]
        Resource = module.dynamodb.urls_table_arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = module.sqs.queue_arn
      }
    ]
  })

  depends_on = [null_resource.bundle_shared]
}

# =============================================================================
# Lambda: Analytics (SQS trigger)
# Needs: SQS receive/delete, DynamoDB write to clicks + update urls
# =============================================================================
module "lambda_analytics" {
  source        = "./modules/lambda"
  project_name  = var.project_name
  function_name = "analytics"
  source_dir    = "../src/analytics"
  timeout       = 30

  environment_variables = {
    URLS_TABLE   = module.dynamodb.urls_table_name
    CLICKS_TABLE = module.dynamodb.clicks_table_name
  }

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = module.sqs.queue_arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ]
        Resource = [
          module.dynamodb.urls_table_arn,
          module.dynamodb.clicks_table_arn,
        ]
      }
    ]
  })

  depends_on = [null_resource.bundle_shared]
}

# SQS → Lambda trigger
resource "aws_lambda_event_source_mapping" "sqs_to_analytics" {
  event_source_arn                   = module.sqs.queue_arn
  function_name                      = module.lambda_analytics.function_arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  function_response_types            = ["ReportBatchItemFailures"]
}

# =============================================================================
# Lambda: Stats
# Needs: DynamoDB read from both tables
# =============================================================================
module "lambda_stats" {
  source        = "./modules/lambda"
  project_name  = var.project_name
  function_name = "stats"
  source_dir    = "../src/stats"

  environment_variables = {
    URLS_TABLE   = module.dynamodb.urls_table_name
    CLICKS_TABLE = module.dynamodb.clicks_table_name
  }

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
      ]
      Resource = [
        module.dynamodb.urls_table_arn,
        module.dynamodb.clicks_table_arn,
      ]
    }]
  })

  depends_on = [null_resource.bundle_shared]
}

# =============================================================================
# API Gateway
# =============================================================================
module "api_gateway" {
  source       = "./modules/api_gateway"
  project_name = var.project_name

  shortener_invoke_arn    = module.lambda_shortener.invoke_arn
  shortener_function_name = module.lambda_shortener.function_name

  redirect_invoke_arn    = module.lambda_redirect.invoke_arn
  redirect_function_name = module.lambda_redirect.function_name

  stats_invoke_arn    = module.lambda_stats.invoke_arn
  stats_function_name = module.lambda_stats.function_name
}
