---
description: Deploy a serverless AI application to AWS with Lambda, API Gateway, S3, CloudFront, Bedrock, Terraform IaC, and GitHub Actions CI/CD
---

# Workflow: AWS Serverless AI Application Deployment

This workflow guides an AI agent through building and deploying a full-stack AI application on AWS using serverless architecture with Infrastructure as Code and CI/CD automation.

## Prerequisites Checklist

Before starting, verify the following are in place:
- AWS CLI configured (`aws configure`) with IAM user that has admin or sufficient permissions
- Docker Desktop installed and running (for Lambda packaging)
- Terraform installed (`terraform --version`)
- Node.js 18+ and npm installed
- Python 3.12+ and `uv` installed
- GitHub repository created and local git initialized

---

## Phase 1: Project Structure Setup

### Step 1: Create base directory structure

```
project-root/
├── backend/
│   ├── data/              # AI persona/context files
│   ├── server.py          # FastAPI application
│   ├── lambda_handler.py  # Mangum adapter for Lambda
│   ├── context.py         # System prompt builder
│   ├── resources.py       # Data loader
│   ├── deploy.py          # Lambda packaging script
│   └── requirements.txt
├── frontend/              # Next.js or similar SPA
├── terraform/             # All IaC files
├── scripts/               # Deploy and destroy scripts
├── .github/workflows/     # CI/CD pipelines
├── docs/dev/              # Developer documentation
├── .env.example
└── .gitignore
```

### Step 2: Create .gitignore

Must include at minimum:
```
.env
.env.*
!.env.example
.terraform/
*.tfstate
*.tfstate.*
.terraform.lock.hcl
terraform.tfstate.d/
*.tfvars
lambda-deployment.zip
lambda-package/
node_modules/
.next/
out/
__pycache__/
*.pyc
.venv/
memory/
```

---

## Phase 2: Backend — FastAPI Lambda

### Step 1: FastAPI application (server.py)

Core structure:
- FastAPI app with CORS configured from `CORS_ORIGINS` env variable
- Routes: `GET /`, `GET /health`, `POST /chat`
- Session-based conversation memory (S3 for production, local files for dev)
- AI client configured via environment variables

### Step 2: Lambda handler (lambda_handler.py)

```python
from mangum import Mangum
from server import app

handler = Mangum(app, lifespan="off")
```

### Step 3: Lambda packaging (deploy.py)

Use Docker to build Lambda-compatible zip:
- Base image: `public.ecr.aws/lambda/python:3.12`
- Install dependencies from requirements.txt
- Copy application files
- Output: `lambda-deployment.zip`

Key requirements.txt packages:
```
fastapi
mangum
boto3
```

### Step 4: Test locally

```bash
cd backend
uv run uvicorn server:app --reload
# Test: http://localhost:8000/health
```

---

## Phase 3: Frontend — Next.js Static Export

### Step 1: Configure for static export

In `next.config.ts`:
```typescript
const nextConfig: NextConfig = {
  output: 'export',
  trailingSlash: true,
  images: { unoptimized: true },
};
```

### Step 2: Environment variable for API URL

Read from `NEXT_PUBLIC_API_URL` — set at build time via `.env.production`.

### Step 3: Test locally

```bash
cd frontend
npm install
npm run dev
# Test: http://localhost:3000
```

---

## Phase 4: Terraform Infrastructure (main.tf)

Create all resources in this order (dependencies matter):

### Resources to create:

1. **S3 — Memory bucket** (private, versioning optional)
2. **S3 — Frontend bucket** (public read, static website enabled)
   - `aws_s3_bucket_website_configuration` with index/error documents
   - Bucket policy allowing `s3:GetObject` for `Principal: "*"`
3. **IAM Role — Lambda**
   - Trust policy: `lambda.amazonaws.com`
   - Attach: `AWSLambdaBasicExecutionRole`, `AmazonBedrockFullAccess`, `AmazonS3FullAccess`
4. **Lambda Function**
   - Runtime: `python3.12`, Architecture: `x86_64`
   - Environment vars: `CORS_ORIGINS`, `S3_BUCKET`, `USE_S3`, `BEDROCK_MODEL_ID`
   - `source_code_hash = filebase64sha256("../backend/lambda-deployment.zip")`
   - `depends_on = [aws_cloudfront_distribution.main]` (CORS needs CF URL)
5. **API Gateway HTTP API** (aws_apigatewayv2_api)
   - CORS allow_origins: `["*"]` (tighten later)
   - Routes: `GET /`, `POST /chat`, `GET /health`
   - Lambda integration + Lambda permission
6. **CloudFront Distribution**
   - Origin: S3 website endpoint (http-only)
   - `default_root_object = "index.html"`
   - Custom error: 404 → 200 `/index.html` (SPA routing)
   - `viewer_protocol_policy = "redirect-to-https"`

### Variables (variables.tf):

```hcl
variable "project_name" { type = string }
variable "environment"  { 
  type = string
  validation {
    condition = contains(["dev", "test", "prod"], var.environment)
  }
}
variable "bedrock_model_id" { default = "amazon.nova-micro-v1:0" }
variable "lambda_timeout"   { default = 60 }
```

### Naming convention:

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}
# All resources: "${local.name_prefix}-{resource}-${data.aws_caller_identity.current.account_id}"
```

### Outputs (outputs.tf):

Always expose:
- `api_gateway_url`
- `cloudfront_url`
- `s3_frontend_bucket`
- `s3_memory_bucket`
- `lambda_function_name`
- `cloudfront_distribution_id`

### Provider config (versions.tf):

```hcl
provider "aws" {
  region = "eu-west-2"  # or your preferred region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"  # Required for ACM certificates with CloudFront
}
```

---

## Phase 5: Deploy Scripts

### deploy.ps1 / deploy.sh (same logic, different syntax)

Steps in order:
1. `cd backend && uv run deploy.py` — build Lambda zip
2. `cd terraform && terraform init` (with S3 backend flags after Phase 6)
3. `terraform workspace new/select {environment}`
4. `terraform apply -var="project_name=..." -var="environment=..." -auto-approve`
5. `terraform output -raw api_gateway_url` → save to variable
6. `terraform output -raw s3_frontend_bucket` → save to variable
7. `cd frontend && echo "NEXT_PUBLIC_API_URL={url}" > .env.production`
8. `npm install && npm run build`
9. `aws s3 sync ./out s3://{bucket}/ --delete`

### destroy.ps1 / destroy.sh

Steps in order:
1. `terraform init` (with S3 backend)
2. Check workspace exists
3. `terraform workspace select {environment}`
4. Empty S3 buckets: `aws s3 rm s3://{bucket} --recursive`
5. Create dummy `lambda-deployment.zip` if missing (terraform needs it for plan)
6. `terraform destroy -auto-approve`

---

## Phase 6: Terraform Remote State (S3 Backend)

This must be done ONCE per AWS account before setting up CI/CD.

### Step 1: Create backend-setup.tf temporarily

Create S3 bucket + DynamoDB table for state management:
- Bucket: `{project}-terraform-state-{account_id}` (versioning + encryption + private)
- DynamoDB: `{project}-terraform-locks` (LockID hash key, PAY_PER_REQUEST)

### Step 2: Apply ONLY backend resources

```powershell
terraform workspace select default
terraform init
terraform apply -target=aws_s3_bucket.terraform_state -target=aws_s3_bucket_versioning.terraform_state -target=aws_s3_bucket_server_side_encryption_configuration.terraform_state -target=aws_s3_bucket_public_access_block.terraform_state -target=aws_dynamodb_table.terraform_locks
```

### Step 3: Delete backend-setup.tf

Remove the file — resources exist in AWS now.

### Step 4: Create backend.tf

```hcl
terraform {
  backend "s3" {
    # Values passed via -backend-config flags at init time
  }
}
```

### Step 5: Update deploy + destroy scripts

Replace `terraform init -input=false` with:
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-eu-west-2}
terraform init -input=false \
  -backend-config="bucket={project}-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table={project}-terraform-locks" \
  -backend-config="encrypt=true"
```

---

## Phase 7: GitHub Actions CI/CD

### Step 1: Create AWS OIDC role (github-oidc.tf)

Create temporarily, apply, then delete the file:

Resources needed:
- `aws_iam_openid_connect_provider.github` (url: `https://token.actions.githubusercontent.com`)
  - **Check first**: `aws iam list-open-id-connect-providers | grep token.actions.githubusercontent.com`
  - If exists: import it first before applying
- `aws_iam_role.github_actions` with trust policy for your specific GitHub repo
- Policy attachments (Lambda, S3, API Gateway, CloudFront, IAM CRUD, Bedrock, DynamoDB, ACM, Route53)

Apply with (Scenario A — OIDC does not exist):
```powershell
terraform workspace select default
terraform apply -target="aws_iam_openid_connect_provider.github" -target="aws_iam_role.github_actions" [all other targets...] -var="github_repository=OWNER/REPO"
```

Save the output `github_actions_role_arn` — needed for GitHub Secrets.

### Step 2: Set GitHub Repository Secrets

Go to: GitHub Repo → Settings → Secrets and variables → Actions

Required secrets:
| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::{account}:role/github-actions-{project}-deploy` |
| `AWS_ACCOUNT_ID` | Your 12-digit account ID |
| `DEFAULT_AWS_REGION` | `eu-west-2` (or your region) |

### Step 3: Create deploy.yml workflow

Key elements:
```yaml
on:
  push:
    branches: [main]        # Auto-deploy on push
  workflow_dispatch:         # Manual trigger with environment choice
    inputs:
      environment:
        type: choice
        options: [dev, test, prod]

permissions:
  id-token: write            # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ secrets.DEFAULT_AWS_REGION }}
      - run: chmod +x scripts/deploy.sh && ./scripts/deploy.sh {environment}
      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id {id from terraform output} \
            --paths "/*"
```

### Step 4: Create destroy.yml workflow

Always require manual trigger + confirmation:
```yaml
on:
  workflow_dispatch:
    inputs:
      environment: { type: choice, options: [dev, test, prod] }
      confirm:
        description: 'Type environment name to confirm'
        required: true
```

---

## Phase 8: Git + Push

```bash
git init -b main
git add .
git commit -m "Initial commit: {project} infrastructure and application"
git remote add origin https://github.com/OWNER/REPO.git
git push -u origin main
```

**Important:** Always run `git add` from the **project root**, not a subdirectory!

---

## Troubleshooting Reference

### State lock stuck
```bash
# First init the backend locally
terraform init -reconfigure \
  -backend-config="bucket=..." \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=eu-west-2" \
  -backend-config="dynamodb_table=..."

terraform workspace select dev
terraform force-unlock {LOCK_ID}

# If force-unlock fails with "unexpected end of JSON input":
# Delete the lock directly from DynamoDB
aws dynamodb delete-item \
  --table-name {project}-terraform-locks \
  --key '{"LockID":{"S":"{bucket}/env:/dev/dev/terraform.tfstate"}}' \
  --region eu-west-2
```

### lambda-deployment.zip missing during destroy
Destroy scripts must create a dummy file:
```bash
if [ ! -f "../backend/lambda-deployment.zip" ]; then
    echo "dummy" > ../backend/lambda-deployment.zip
fi
```

### CloudFront distribution won't delete
AWS pricing plan change may prevent deletion. Solution:
- Disable the distribution manually in AWS Console
- Leave it disabled (no cost) and proceed
- All other resources will be destroyed normally

### Backend not initialized (workspace/force-unlock fails)
Must run `terraform init -reconfigure` with backend-config flags before any other commands.

### OIDC provider already exists in AWS account
```bash
# Import instead of creating
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform import aws_iam_openid_connect_provider.github \
  "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
```

---

## Bedrock Model Reference

| Region Prefix | Model ID |
|---|---|
| `eu-west-2` | `eu.amazon.nova-lite-v1:0` |
| `us-east-1` | `us.amazon.nova-lite-v1:0` |
| Global | `amazon.nova-micro-v1:0` (cheapest) |

---

## Key Architectural Decisions & Rationale

| Decision | Why |
|---|---|
| Lambda over EC2/ECS | Zero cold-start cost, pay-per-request, no server management |
| Mangum adapter | Bridges FastAPI (ASGI) ↔ Lambda event format |
| S3 static hosting + CloudFront | Cheapest, fastest static site delivery globally |
| Terraform workspaces | Same codebase → multiple environments, no code duplication |
| S3 backend for Terraform state | Enables CI/CD + team collaboration, prevents state conflicts |
| OIDC over access keys | No long-lived credentials, per-job temporary tokens, audit trail |
| `output: 'export'` in Next.js | Required for S3/CloudFront static hosting (no SSR server) |
| Docker for Lambda packaging | Ensures Linux-compatible native dependencies |
