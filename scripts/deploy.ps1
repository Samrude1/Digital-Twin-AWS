param(
    [string]$Environment = "dev",   # dev | test | prod
    [string]$ProjectName = "twin"
)
$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "`n!! ERROR: $msg" -ForegroundColor Red; exit 1 }

Write-Host "`n======================================" -ForegroundColor Yellow
Write-Host "  Deploying $ProjectName to $Environment" -ForegroundColor Yellow
Write-Host "======================================`n" -ForegroundColor Yellow

# 1. Build Lambda package
Write-Step "Building Lambda package..."
Set-Location (Split-Path $PSScriptRoot -Parent)   # project root
Set-Location backend
uv run deploy.py
if ($LASTEXITCODE -ne 0) { Write-Fail "Lambda build failed!" }
Write-Ok "Lambda package built"
Set-Location ..

# 2. Terraform init + workspace + apply
Write-Step "Running terraform init..."
Set-Location terraform
$awsAccountId = aws sts get-caller-identity --query Account --output text
$awsRegion = if ($env:DEFAULT_AWS_REGION) { $env:DEFAULT_AWS_REGION } else { "eu-west-2" }
terraform init -input=false `
  -backend-config="bucket=twin-terraform-state-$awsAccountId" `
  -backend-config="key=$Environment/terraform.tfstate" `
  -backend-config="region=$awsRegion" `
  -backend-config="dynamodb_table=twin-terraform-locks" `
  -backend-config="encrypt=true"
if ($LASTEXITCODE -ne 0) { Write-Fail "terraform init failed!" }

$workspaces = terraform workspace list
if (-not ($workspaces | Select-String "^\s*\*?\s*$Environment\s*$")) {
    terraform workspace new $Environment
} else {
    terraform workspace select $Environment
}

Write-Step "Running terraform apply..."
if ($Environment -eq "prod") {
    terraform apply -var-file="prod.tfvars" -var="project_name=$ProjectName" -var="environment=$Environment" -auto-approve
} else {
    terraform apply -var="project_name=$ProjectName" -var="environment=$Environment" -auto-approve
}
if ($LASTEXITCODE -ne 0) { Write-Fail "terraform apply failed - check errors above." }
Write-Ok "Terraform apply complete"

# 3. Read and validate outputs
Write-Step "Reading Terraform outputs..."
$ApiUrl         = terraform output -raw api_gateway_url 2>$null
$FrontendBucket = terraform output -raw s3_frontend_bucket 2>$null
$CfUrl          = terraform output -raw cloudfront_url 2>$null
$CustomUrl      = ""
try { $CustomUrl = terraform output -raw custom_domain_url 2>$null } catch {}

if ([string]::IsNullOrWhiteSpace($ApiUrl) -or ($ApiUrl -match "Warning")) {
    Write-Fail "Could not read api_gateway_url from Terraform. Did the apply succeed?"
}
if ([string]::IsNullOrWhiteSpace($FrontendBucket) -or ($FrontendBucket -match "Warning")) {
    Write-Fail "Could not read s3_frontend_bucket from Terraform. Did the apply succeed?"
}
Write-Ok "API URL:         $ApiUrl"
Write-Ok "Frontend Bucket: $FrontendBucket"

# 4. Build + deploy frontend
Write-Step "Building and deploying frontend..."
Set-Location ..\frontend
"NEXT_PUBLIC_API_URL=$ApiUrl" | Out-File .env.production -Encoding utf8
npm install
if ($LASTEXITCODE -ne 0) { Write-Fail "npm install failed!" }
npm run build
if ($LASTEXITCODE -ne 0) { Write-Fail "npm build failed!" }
aws s3 sync .\out "s3://$FrontendBucket/" --delete
if ($LASTEXITCODE -ne 0) { Write-Fail "S3 sync failed!" }
Set-Location ..

# 5. Final summary
Write-Host "`n======================================" -ForegroundColor Green
Write-Host "  Deployment complete!" -ForegroundColor Green
Write-Host "  CloudFront : $CfUrl" -ForegroundColor Cyan
Write-Host "  API Gateway: $ApiUrl" -ForegroundColor Cyan
if ($CustomUrl) { Write-Host "  Domain     : $CustomUrl" -ForegroundColor Cyan }
Write-Host "======================================`n" -ForegroundColor Green