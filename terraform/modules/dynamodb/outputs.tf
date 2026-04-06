output "urls_table_name" {
  value = aws_dynamodb_table.urls.name
}

output "urls_table_arn" {
  value = aws_dynamodb_table.urls.arn
}

output "clicks_table_name" {
  value = aws_dynamodb_table.clicks.name
}

output "clicks_table_arn" {
  value = aws_dynamodb_table.clicks.arn
}
