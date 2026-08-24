# Data source to get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# AWS Managed Security Headers policy for CloudFront
data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

locals {
  aliases = var.use_custom_domain && var.root_domain != "" ? [
    var.root_domain,
    "www.${var.root_domain}"
  ] : []

  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# S3 bucket for conversation memory
resource "aws_s3_bucket" "memory" {
  bucket = "${local.name_prefix}-memory-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "memory" {
  bucket = aws_s3_bucket.memory.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "memory" {
  bucket = aws_s3_bucket.memory.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# S3 bucket for frontend static website
resource "aws_s3_bucket" "frontend" {
  bucket = "${local.name_prefix}-frontend-${data.aws_caller_identity.current.account_id}"
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

# ─────────────────────────────────────────────────────────────────────────────
# Cost Protection Infrastructure
# ─────────────────────────────────────────────────────────────────────────────

# DynamoDB table for daily cost tracking (used by Python circuit breaker)
resource "aws_dynamodb_table" "cost_tracker" {
  name         = "${local.name_prefix}-cost-tracker"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "date"
  tags         = local.common_tags

  attribute {
    name = "date"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# SNS topic for budget alerts and circuit-breaker notifications
resource "aws_sns_topic" "budget_alarm" {
  name = "${local.name_prefix}-budget-alarm"
  tags = local.common_tags
}

# Optional: email subscription (created only when budget_alert_email is set)
resource "aws_sns_topic_subscription" "budget_email" {
  count     = var.budget_alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.budget_alarm.arn
  protocol  = "email"
  endpoint  = var.budget_alert_email
}

# IAM role for the budget breaker Lambda
resource "aws_iam_role" "budget_breaker_role" {
  name = "${local.name_prefix}-budget-breaker-role"
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "budget_breaker_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.budget_breaker_role.name
}

resource "aws_iam_role_policy" "budget_breaker_policy" {
  name = "${local.name_prefix}-budget-breaker-policy"
  role = aws_iam_role.budget_breaker_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow killing the main API Lambda by setting concurrency to 0
        Action   = ["lambda:PutFunctionConcurrency", "lambda:GetFunctionConcurrency"]
        Effect   = "Allow"
        Resource = "arn:aws:lambda:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:function:${local.name_prefix}-api"
      },
      {
        # Allow sending the shutdown notification
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.budget_alarm.arn
      }
    ]
  })
}

# Budget breaker Lambda (triggered by SNS when monthly budget threshold is hit)
resource "aws_lambda_function" "budget_breaker" {
  filename         = "${path.module}/../backend/budget_breaker.zip"
  function_name    = "${local.name_prefix}-budget-breaker"
  role             = aws_iam_role.budget_breaker_role.arn
  handler          = "budget_breaker.handler"
  runtime          = "python3.12"
  timeout          = 30
  tags             = local.common_tags

  # The zip is created from budget_breaker.py by the deploy script.
  # source_code_hash forces re-deploy when the file changes.
  source_code_hash = filebase64sha256("${path.module}/../backend/budget_breaker.zip")

  environment {
    variables = {
      MAIN_FUNCTION_NAME  = "${local.name_prefix}-api"
      ALERT_SNS_TOPIC_ARN = aws_sns_topic.budget_alarm.arn
      MONTHLY_BUDGET_USD  = tostring(var.monthly_budget_usd)
    }
  }
}

# Allow SNS to invoke the budget breaker Lambda
resource "aws_lambda_permission" "budget_breaker_sns" {
  statement_id  = "AllowSNSTrigger"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_breaker.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_alarm.arn
}

# Subscribe the budget breaker Lambda to the SNS topic
resource "aws_sns_topic_subscription" "budget_lambda" {
  topic_arn = aws_sns_topic.budget_alarm.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.budget_breaker.arn
}

# AWS Budgets: monthly cost alert → triggers SNS at 80% of limit
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name_prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alarm.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alarm.arn]
  }

  tags = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Scoped IAM policies for the main API Lambda
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role_policy" "lambda_bedrock_policy" {
  name = "${local.name_prefix}-lambda-bedrock-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "bedrock:Converse",
          "bedrock:InvokeModel"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/amazon.nova-*"
      },
      {
        Action = [
          "bedrock:GetGuardrail",
          "bedrock:ApplyGuardrail"
        ]
        Effect   = "Allow"
        Resource = [aws_bedrock_guardrail.main.guardrail_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${local.name_prefix}-lambda-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.memory.arn,
          "${aws_s3_bucket.memory.arn}/*"
        ]
      }
    ]
  })
}

# Allow the main API Lambda to read/write the cost tracking table
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${local.name_prefix}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.cost_tracker.arn
      }
    ]
  })
}

# Bedrock Guardrail
resource "aws_bedrock_guardrail" "main" {
  name                      = "${local.name_prefix}-guardrail"
  blocked_input_messaging   = "I apologize, but I cannot assist with that specific request as it falls outside my professional guidelines."
  blocked_outputs_messaging = "I apologize, but I cannot provide that information as it falls outside my professional guidelines."
  description               = "Professional guardrails for Sami Rautanen's Digital Twin"

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
  }

  topic_policy_config {
    topics_config {
      name       = "Medical_Financial_Advice"
      examples   = ["What medicine should I take for a fever?", "How should I invest my inheritance?", "What is the best crypto to buy right now?"]
      type       = "DENY"
      definition = "Providing specific medical, legal, or financial investment advice."
    }
  }

  tags = local.common_tags
}

resource "aws_bedrock_guardrail_version" "main" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "V1 of professional guardrails"
}

# Lambda function
resource "aws_lambda_function" "api" {
  filename         = "${path.module}/../backend/lambda-deployment.zip"
  function_name    = "${local.name_prefix}-api"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_handler.handler"
  source_code_hash = filebase64sha256("${path.module}/../backend/lambda-deployment.zip")
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  timeout          = var.lambda_timeout
  tags             = local.common_tags

  environment {
    variables = {
      CORS_ORIGINS      = var.use_custom_domain ? "https://${var.root_domain},https://www.${var.root_domain}" : "https://${aws_cloudfront_distribution.main.domain_name}"
      S3_BUCKET         = aws_s3_bucket.memory.id
      USE_S3            = "true"
      BEDROCK_MODEL_ID  = var.bedrock_model_id
      GUARDRAIL_ID      = aws_bedrock_guardrail.main.guardrail_id
      GUARDRAIL_VERSION = aws_bedrock_guardrail_version.main.version
      # Cost protection
      COST_TABLE        = aws_dynamodb_table.cost_tracker.name
      DAILY_BUDGET_USD  = tostring(var.daily_budget_usd)
    }
  }

  # Ensure Lambda waits for the distribution to exist
  depends_on = [aws_cloudfront_distribution.main]
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name_prefix}-api-gateway"
  protocol_type = "HTTP"
  tags          = local.common_tags

  cors_configuration {
    allow_credentials = false
    allow_headers     = ["*"]
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_origins     = var.use_custom_domain ? ["https://${var.root_domain}", "https://www.${var.root_domain}"] : ["https://${aws_cloudfront_distribution.main.domain_name}"]
    max_age           = 300
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
  tags        = local.common_tags

  default_route_settings {
    throttling_burst_limit = var.api_throttle_burst_limit
    throttling_rate_limit  = var.api_throttle_rate_limit
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "get_root" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "post_chat" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "main" {
  aliases = local.aliases
  
  viewer_certificate {
    acm_certificate_arn            = var.use_custom_domain ? aws_acm_certificate.site[0].arn : null
    cloudfront_default_certificate = var.use_custom_domain ? false : true
    ssl_support_method             = var.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  tags                = local.common_tags

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
    min_ttl                    = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
}

# Optional: Custom domain configuration (only created when use_custom_domain = true)
data "aws_route53_zone" "root" {
  count        = var.use_custom_domain ? 1 : 0
  name         = var.root_domain
  private_zone = false
}

resource "aws_acm_certificate" "site" {
  count                     = var.use_custom_domain ? 1 : 0
  provider                  = aws.us_east_1
  domain_name               = var.root_domain
  subject_alternative_names = ["www.${var.root_domain}"]
  validation_method         = "DNS"
  lifecycle { create_before_destroy = true }
  tags = local.common_tags
}

resource "aws_route53_record" "site_validation" {
  for_each = var.use_custom_domain ? {
    for dvo in aws_acm_certificate.site[0].domain_validation_options :
    dvo.domain_name => dvo
  } : {}

  zone_id = data.aws_route53_zone.root[0].zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 300
  records = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "site" {
  count           = var.use_custom_domain ? 1 : 0
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.site[0].arn
  validation_record_fqdns = [
    for r in aws_route53_record.site_validation : r.fqdn
  ]
}

resource "aws_route53_record" "alias_root" {
  count   = var.use_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.root[0].zone_id
  name    = var.root_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_root_ipv6" {
  count   = var.use_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.root[0].zone_id
  name    = var.root_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_www" {
  count   = var.use_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.root[0].zone_id
  name    = "www.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_www_ipv6" {
  count   = var.use_custom_domain ? 1 : 0
  zone_id = data.aws_route53_zone.root[0].zone_id
  name    = "www.${var.root_domain}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}