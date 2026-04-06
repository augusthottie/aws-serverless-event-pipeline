# =============================================================================
# Dead Letter Queue
# Failed clicks go here after 3 retries
# =============================================================================
resource "aws_sqs_queue" "clicks_dlq" {
  name                      = "${var.project_name}-clicks-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "${var.project_name}-clicks-dlq"
  }
}

# =============================================================================
# Main Clicks Queue
# =============================================================================
resource "aws_sqs_queue" "clicks" {
  name                       = "${var.project_name}-clicks"
  visibility_timeout_seconds = 60  # Must be >= Lambda timeout
  message_retention_seconds  = 345600  # 4 days
  receive_wait_time_seconds  = 20  # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.clicks_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.project_name}-clicks"
  }
}
