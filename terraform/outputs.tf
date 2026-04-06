output "api_url" {
  description = "API Gateway URL - use this for all endpoints"
  value       = module.api_gateway.api_url
}

output "shorten_endpoint" {
  value = "${module.api_gateway.api_url}/shorten"
}

output "stats_endpoint_example" {
  value = "${module.api_gateway.api_url}/stats/{code}"
}

output "urls_table" {
  value = module.dynamodb.urls_table_name
}

output "clicks_table" {
  value = module.dynamodb.clicks_table_name
}

output "clicks_queue_url" {
  value = module.sqs.queue_url
}

output "clicks_dlq_url" {
  value = module.sqs.dlq_url
}
