variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "shortener"
}

variable "base_url" {
  type        = string
  description = "Base URL for short links (updated with API Gateway URL after first apply)"
  default     = "https://short.example.com"
}
