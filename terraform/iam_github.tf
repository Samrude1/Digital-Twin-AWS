# GitHub Actions IAM Role — documentation as code
#
# This file documents the IAM role used by GitHub Actions CI/CD.
# The role was originally created manually and is kept here for reference.
#
# Current state (verified 2026-06-12):
#   Role name : github-actions-twin-deploy
#   ARN       : arn:aws:iam::178566695644:role/github-actions-twin-deploy
#   OIDC      : arn:aws:iam::178566695644:oidc-provider/token.actions.githubusercontent.com
#
# Attached managed policies (10/10 — AWS limit reached):
#   - AmazonRoute53FullAccess
#   - AmazonAPIGatewayAdministrator
#   - CloudFrontFullAccess
#   - AWSCertificateManagerFullAccess
#   - IAMReadOnlyAccess
#   - AmazonSNSFullAccess          ← added 2026-06-12
#   - AmazonDynamoDBFullAccess
#   - AmazonS3FullAccess
#   - AmazonBedrockFullAccess
#   - AWSLambda_FullAccess
#
# Inline policy "github-actions-additional" covers:
#   - IAM write actions (CreateRole, PutRolePolicy, PassRole …)
#   - STS:GetCallerIdentity
#   - AWS Budgets (CreateBudget, ModifyBudget …)  ← added 2026-06-12
#   - CloudWatch Logs (CreateLogGroup, TagResource …) ← added 2026-06-12
#
# NOTE: This role is NOT managed by this Terraform workspace.
#       It lives in the root AWS account and is shared across workspaces.
#       Changes must be made via AWS CLI or the AWS Console.
#       The inline policy is reproduced below for audit / documentation purposes.

# ─────────────────────────────────────────────────────────────────────────────
# Inline policy reference (applied via AWS CLI — not managed here)
# ─────────────────────────────────────────────────────────────────────────────
#
# aws iam put-role-policy \
#   --role-name github-actions-twin-deploy \
#   --policy-name github-actions-additional \
#   --policy-document file://iam_github_inline_policy.json
#
# Content of iam_github_inline_policy.json:
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Sid": "IAMAndSTS",
#       "Effect": "Allow",
#       "Action": [
#         "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy",
#         "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
#         "iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies",
#         "iam:ListAttachedRolePolicies", "iam:UpdateAssumeRolePolicy",
#         "iam:PassRole", "iam:TagRole", "iam:UntagRole",
#         "iam:ListInstanceProfilesForRole", "sts:GetCallerIdentity"
#       ],
#       "Resource": "*"
#     },
#     {
#       "Sid": "BudgetsDeploy",
#       "Effect": "Allow",
#       "Action": [
#         "budgets:CreateBudget", "budgets:DeleteBudget",
#         "budgets:DescribeBudget", "budgets:ModifyBudget",
#         "budgets:ViewBudget", "budgets:DescribeBudgets",
#         "budgets:DescribeBudgetActionsForBudget",
#         "budgets:DescribeBudgetActionsForAccount",
#         "budgets:DescribeBudgetNotificationsForAccount"
#       ],
#       "Resource": "*"
#     },
#     {
#       "Sid": "CloudWatchLogs",
#       "Effect": "Allow",
#       "Action": [
#         "logs:CreateLogGroup", "logs:DeleteLogGroup",
#         "logs:DescribeLogGroups", "logs:ListTagsForResource",
#         "logs:ListTagsLogGroup", "logs:PutRetentionPolicy",
#         "logs:TagLogGroup", "logs:TagResource",
#         "logs:UntagLogGroup", "logs:UntagResource"
#       ],
#       "Resource": "*"
#     }
#   ]
# }
