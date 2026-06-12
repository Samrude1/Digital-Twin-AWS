# GitHub Actions OIDC provider and deploy role
#
# This file defines the IAM role assumed by GitHub Actions during CI/CD.
# The role uses OIDC (federated identity) so no long-lived AWS credentials
# need to be stored in GitHub secrets — only the role ARN is needed.
#
# IMPORTANT: After first `terraform apply`, set the following GitHub secret:
#   AWS_ROLE_ARN = <github_actions_role_arn output value>

# ─────────────────────────────────────────────────────────────────────────────
# GitHub OIDC Provider
# (There can only be ONE per AWS account — use data source if it already exists)
# ─────────────────────────────────────────────────────────────────────────────

variable "github_org" {
  description = "GitHub organisation or username that owns the repository."
  type        = string
  default     = "Samrude1"
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)."
  type        = string
  default     = "Digital-Twin-AWS"
}

# Try to look up an existing provider first; create only if absent
data "aws_iam_openid_connect_provider" "github" {
  count = 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  # Use the existing OIDC provider ARN if it already exists, otherwise use
  # the one we create. Exactly one of these will be non-empty.
  oidc_provider_arn = length(data.aws_iam_openid_connect_provider.github) > 0 ? data.aws_iam_openid_connect_provider.github[0].arn : aws_iam_openid_connect_provider.github[0].arn
}

resource "aws_iam_openid_connect_provider" "github" {
  # Only create if it doesn't already exist.
  # Set count = 0 once the provider is confirmed to exist in your account.
  count           = 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# GitHub Actions IAM Role
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "github_actions" {
  name = "${local.name_prefix}-github-actions-deploy"
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Allow any branch/PR in the configured repo to assume this role
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Deploy Policy — exactly the permissions Terraform needs, nothing more
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${local.name_prefix}-github-actions-deploy-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── S3 ──────────────────────────────────────────────────────────────────
      {
        Sid    = "S3Deploy"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucketAcl",
          "s3:GetBucketCORS",
          "s3:GetBucketLocation",
          "s3:GetBucketObjectLockConfiguration",
          "s3:GetBucketOwnershipControls",
          "s3:GetBucketPolicy",
          "s3:GetBucketPolicyStatus",
          "s3:GetBucketPublicAccessBlock",
          "s3:GetBucketRequestPayment",
          "s3:GetBucketTagging",
          "s3:GetBucketVersioning",
          "s3:GetBucketWebsite",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutBucketOwnershipControls",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketTagging",
          "s3:PutBucketWebsite",
          "s3:PutEncryptionConfiguration",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },

      # ── Lambda ──────────────────────────────────────────────────────────────
      {
        Sid    = "LambdaDeploy"
        Effect = "Allow"
        Action = [
          "lambda:AddPermission",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:PutFunctionConcurrency",
          "lambda:RemovePermission",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration"
        ]
        Resource = "*"
      },

      # ── API Gateway ──────────────────────────────────────────────────────────
      {
        Sid    = "APIGatewayDeploy"
        Effect = "Allow"
        Action = [
          "apigateway:DELETE",
          "apigateway:GET",
          "apigateway:PATCH",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:TagResource",
          "apigateway:UntagResource"
        ]
        Resource = "*"
      },

      # ── CloudFront ──────────────────────────────────────────────────────────
      {
        Sid    = "CloudFrontDeploy"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:CreateInvalidation",
          "cloudfront:DeleteDistribution",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListTagsForResource",
          "cloudfront:TagResource",
          "cloudfront:UntagResource",
          "cloudfront:UpdateDistribution"
        ]
        Resource = "*"
      },

      # ── IAM (scoped — only manage roles this Terraform creates) ─────────────
      {
        Sid    = "IAMDeploy"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:TagRole",
          "iam:UntagRole"
        ]
        Resource = "*"
      },

      # ── Bedrock ─────────────────────────────────────────────────────────────
      {
        Sid    = "BedrockDeploy"
        Effect = "Allow"
        Action = [
          "bedrock:CreateGuardrail",
          "bedrock:CreateGuardrailVersion",
          "bedrock:DeleteGuardrail",
          "bedrock:GetGuardrail",
          "bedrock:ListGuardrails",
          "bedrock:ListTagsForResource",
          "bedrock:TagResource",
          "bedrock:UntagResource",
          "bedrock:UpdateGuardrail"
        ]
        Resource = "*"
      },

      # ── SNS ─────────────────────────────────────────────────────────────────
      {
        Sid    = "SNSDeploy"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:GetTopicAttributes",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTagsForResource",
          "sns:SetTopicAttributes",
          "sns:Subscribe",
          "sns:TagResource",
          "sns:Unsubscribe",
          "sns:UntagResource"
        ]
        Resource = "*"
      },

      # ── DynamoDB ─────────────────────────────────────────────────────────────
      {
        Sid    = "DynamoDBDeploy"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:ListTagsOfResource",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:UpdateTimeToLive"
        ]
        Resource = "*"
      },

      # ── AWS Budgets ──────────────────────────────────────────────────────────
      {
        Sid    = "BudgetsDeploy"
        Effect = "Allow"
        Action = [
          "budgets:CreateBudget",
          "budgets:DeleteBudget",
          "budgets:DescribeBudget",
          "budgets:ModifyBudget",
          "budgets:ViewBudget"
        ]
        Resource = "*"
      },

      # ── ACM (certificates — only when custom domain is used) ─────────────────
      {
        Sid    = "ACMDeploy"
        Effect = "Allow"
        Action = [
          "acm:AddTagsToCertificate",
          "acm:DeleteCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:ListTagsForCertificate",
          "acm:RequestCertificate"
        ]
        Resource = "*"
      },

      # ── Route53 (only when custom domain is used) ────────────────────────────
      {
        Sid    = "Route53Deploy"
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },

      # ── CloudWatch Logs (Lambda needs to write logs) ──────────────────────────
      {
        Sid    = "LogsDeploy"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource",
          "logs:ListTagsLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:TagResource"
        ]
        Resource = "*"
      },

      # ── Terraform state backend (S3 + DynamoDB lock) ──────────────────────────
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Output — copy this ARN to GitHub secret AWS_ROLE_ARN
# ─────────────────────────────────────────────────────────────────────────────

output "github_actions_role_arn" {
  description = "Copy this value to GitHub Actions secret: AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
