#!/bin/bash
set -e

# Check if environment parameter is provided
if [ $# -eq 0 ] && [ -z "$ENVIRONMENT" ]; then
    echo "❌ Error: Environment parameter is required"
    echo "Usage: $0 <environment>"
    exit 1
fi

ENVIRONMENT=${1:-$ENVIRONMENT}
PROJECT_NAME=${2:-${PROJECT_NAME:-twin}}

echo "🗑️ Preparing to destroy ${PROJECT_NAME}-${ENVIRONMENT} infrastructure..."

# Navigate to terraform directory
cd terraform

# Get AWS Account ID if not provided
if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

# Use DEFAULT_AWS_REGION or fallback to eu-west-2
AWS_REGION=${DEFAULT_AWS_REGION:-eu-west-2}

# Initialize terraform with S3 backend
echo "🔧 Initializing Terraform with S3 backend..."
terraform init -input=false \
  -backend-config="bucket=twin-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=twin-terraform-locks" \
  -backend-config="encrypt=true"

# Select the workspace
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    echo "❌ Error: Workspace '$ENVIRONMENT' does not exist"
    exit 1
fi

terraform workspace select "$ENVIRONMENT"

echo "📦 Emptying S3 buckets..."

FRONTEND_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-frontend-${AWS_ACCOUNT_ID}"
MEMORY_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-memory-${AWS_ACCOUNT_ID}"

# Empty buckets if they exist
aws s3 rm "s3://$FRONTEND_BUCKET" --recursive || echo "Frontend bucket not found or already empty"
aws s3 rm "s3://$MEMORY_BUCKET" --recursive || echo "Memory bucket not found or already empty"

echo "🔥 Running terraform destroy..."

# Run terraform destroy
if [ "$ENVIRONMENT" = "prod" ] && [ -f "prod.tfvars" ]; then
    terraform destroy -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
else
    terraform destroy -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
fi

echo "✅ Infrastructure for ${ENVIRONMENT} has been destroyed!"
