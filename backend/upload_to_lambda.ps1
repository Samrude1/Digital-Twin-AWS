# ============================================================
# Lambda ZIP Upload via S3 (PowerShell)
# ============================================================
# Käyttö: .\upload_to_lambda.ps1
# 
# Tämä skripti:
#   1. Lataa .env-muuttujat
#   2. Luo väliaikaisen S3-bucketin
#   3. Lataa lambda-deployment.zip → S3
#   4. Päivittää Lambda-funktion koodin S3:sta
#   5. Siivoaa väliaikaisen bucketin
#
# Edellytykset:
#   - AWS CLI asennettu ja konfiguroitu
#   - .env-tiedosto projektin juuressa (sisältää DEFAULT_AWS_REGION)
#   - lambda-deployment.zip luotu (uv run deploy.py)
# ============================================================

param(
    [string]$FunctionName = "twin-api",
    [string]$ZipFile = "lambda-deployment.zip",
    [string]$EnvFile = "../.env"
)

# --- Värit ja apufunktiot ---
function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "  Lambda Deploy via S3" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Yellow

# --- 1. Lataa .env ---
Write-Step "Ladataan ympäristömuuttujat (.env)..."
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
        }
    }
    Write-Ok ".env ladattu"
}
else {
    Write-Err ".env-tiedostoa ei löydy polussa: $EnvFile"
    exit 1
}

# --- Tarkista region ---
$region = $env:DEFAULT_AWS_REGION
if (-not $region) {
    Write-Err "DEFAULT_AWS_REGION ei ole asetettu .env-tiedostossa!"
    exit 1
}
Write-Ok "Region: $region"

# --- 2. Tarkista ZIP ---
Write-Step "Tarkistetaan deployment-paketti..."
if (-not (Test-Path $ZipFile)) {
    Write-Err "$ZipFile ei löydy! Aja ensin: uv run deploy.py"
    exit 1
}
$sizeMB = [math]::Round((Get-Item $ZipFile).Length / 1MB, 2)
Write-Ok "$ZipFile löytyi ($sizeMB MB)"

# --- 3. Luo väliaikainen S3-bucket ---
Write-Step "Luodaan väliaikainen S3-bucket..."
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$deployBucket = "lambda-deploy-$timestamp"

aws s3 mb "s3://$deployBucket" --region $region 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err "S3-bucketin luonti epäonnistui!"
    exit 1
}
Write-Ok "Bucket luotu: $deployBucket"

# --- 4. Lataa ZIP → S3 ---
Write-Step "Ladataan $ZipFile → S3..."
aws s3 cp $ZipFile "s3://$deployBucket/" --region $region
if ($LASTEXITCODE -ne 0) {
    Write-Err "S3-upload epäonnistui!"
    # Siivoa bucket ennen poistumista
    aws s3 rb "s3://$deployBucket" --force 2>&1 | Out-Null
    exit 1
}
Write-Ok "Upload valmis"

# --- 5. Päivitä Lambda ---
Write-Step "Päivitetään Lambda-funktio '$FunctionName'..."
$result = aws lambda update-function-code `
    --function-name $FunctionName `
    --s3-bucket $deployBucket `
    --s3-key $ZipFile `
    --region $region 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Err "Lambda-päivitys epäonnistui!"
    Write-Host $result -ForegroundColor Red
}
else {
    Write-Ok "Lambda päivitetty onnistuneesti!"
}

# --- 6. Siivous ---
Write-Step "Siivotaan väliaikainen S3-bucket..."
aws s3 rm "s3://$deployBucket/$ZipFile" 2>&1 | Out-Null
aws s3 rb "s3://$deployBucket" 2>&1 | Out-Null
Write-Ok "Bucket '$deployBucket' poistettu"

# --- Valmis ---
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  ✓ Deploy valmis!" -ForegroundColor Green
Write-Host "  Funktio: $FunctionName" -ForegroundColor Green
Write-Host "  Region:  $region" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
