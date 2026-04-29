#!/bin/bash
set -e

# Support environment variables or command line arguments
ENVIRONMENT=${1:-${ENVIRONMENT:-dev}}
PROJECT_NAME=${2:-${PROJECT_NAME:-twin}}

echo "🚀 Deploying ${PROJECT_NAME} to ${ENVIRONMENT} environment..."

# 1. Build Lambda package
echo "📦 Building Lambda package..."
cd backend
# Using uv to run the build script
uv run deploy.py
cd ..

# 2. Terraform init + workspace + apply
echo "🔧 Running terraform init..."
cd terraform

# Get AWS Account ID if not provided
if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

# Use DEFAULT_AWS_REGION or fallback to us-east-1
AWS_REGION=${DEFAULT_AWS_REGION:-eu-west-2}

terraform init -reconfigure -input=false \
  -backend-config="bucket=twin-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=twin-terraform-locks" \
  -backend-config="encrypt=true"

# Select or create workspace
if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
    terraform workspace new "$ENVIRONMENT"
else
    terraform workspace select "$ENVIRONMENT"
fi

echo "🔨 Running terraform apply..."
if [ "$ENVIRONMENT" = "prod" ] && [ -f "prod.tfvars" ]; then
    terraform apply -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
else
    terraform apply -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
fi

# 3. Read outputs
echo "📋 Reading Terraform outputs..."
API_URL=$(terraform output -raw api_gateway_url | tr -d '"' | xargs)
FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket | tr -d '"' | xargs)

echo "API URL: $API_URL"
echo "Frontend Bucket: $FRONTEND_BUCKET"

# 4. Build + deploy frontend
echo "🏗️ Building and deploying frontend..."
cd ../frontend

# Create .env.production for the frontend build
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.production

npm install
npm run build

# Sync files to S3
aws s3 sync ./out "s3://${FRONTEND_BUCKET}/" --delete

echo "✅ Deployment complete!"
