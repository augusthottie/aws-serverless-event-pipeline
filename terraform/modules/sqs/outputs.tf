output "queue_url" {
  value = aws_sqs_queue.clicks.url
}

output "queue_arn" {
  value = aws_sqs_queue.clicks.arn
}

output "dlq_url" {
  value = aws_sqs_queue.clicks_dlq.url
}

output "dlq_arn" {
  value = aws_sqs_queue.clicks_dlq.arn
}
