variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "bedrock_model_id" {
  description = "Bedrock model ID"
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests/second)"
  type        = number
  default     = 5
}

variable "use_custom_domain" {
  description = "Attach a custom domain to CloudFront"
  type        = bool
  default     = false
}

variable "root_domain" {
  description = "Apex domain name, e.g. mydomain.com"
  type        = string
  default     = ""
}

# Cost Protection

variable "daily_budget_usd" {
  description = "Hard daily cost limit in USD. API returns 503 when exceeded (DynamoDB circuit breaker)."
  type        = number
  default     = 5.0
}

variable "monthly_budget_usd" {
  description = "Monthly AWS cost budget in USD. Triggers SNS alert and Lambda circuit breaker at 80 percent."
  type        = number
  default     = 20.0
}

variable "budget_alert_email" {
  description = "Email address that receives AWS Budget overage alerts and circuit-breaker notifications."
  type        = string
  default     = ""
}