# =============================================================================
# URLs Table
# Primary key: code (string)
# Attributes: url, created_at, clicks
# =============================================================================
resource "aws_dynamodb_table" "urls" {
  name         = "${var.project_name}-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false  # Enable for production
  }

  tags = {
    Name = "${var.project_name}-urls"
  }
}

# =============================================================================
# Clicks Table
# Primary key: code (HASH) + click_id (RANGE)
# GSI: timestamp-index — query clicks by time range
# Attributes: code, click_id, timestamp, user_agent, ip, referer
# =============================================================================
resource "aws_dynamodb_table" "clicks" {
  name         = "${var.project_name}-clicks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"
  range_key    = "click_id"

  attribute {
    name = "code"
    type = "S"
  }

  attribute {
    name = "click_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # GSI to query clicks by timestamp across all codes
  global_secondary_index {
    name            = "timestamp-index"
    hash_key        = "code"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = {
    Name = "${var.project_name}-clicks"
  }
}
