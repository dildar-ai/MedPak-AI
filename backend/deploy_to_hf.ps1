# MedPak AI — Deploy backend to a Hugging Face Docker Space
#
# Prerequisites:
#   1. Create the Space first: https://huggingface.co/new-space
#      Name: medpak-ai-backend | SDK: Docker | Public
#   2. Have an HF write token ready: https://huggingface.co/settings/tokens
#      (git will ask for it as the password; username = your HF username)
#
# Usage (from the backend\ folder):
#   .\deploy_to_hf.ps1 -HfUser <your-hf-username> -SpaceName medpak-ai-backend

param(
    [Parameter(Mandatory = $true)][string]$HfUser,
    [Parameter(Mandatory = $true)][string]$SpaceName
)

$ErrorActionPreference = "Stop"
$HfUser = $HfUser.ToLower()
$SpaceName = $SpaceName.ToLower()

$spaceUrl = "https://huggingface.co/spaces/$HfUser/$SpaceName"
$appUrl = "https://$HfUser-$SpaceName.hf.space"

if (-not (Test-Path ".\main.py")) { throw "Run this script from the backend\ folder." }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Install git first: https://git-scm.com" }

Write-Host "Deploying MedPak AI backend to: $spaceUrl" -ForegroundColor Cyan

$tmp = Join-Path $env:TEMP "medpak_hf_deploy"

if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
git clone $spaceUrl $tmp
if ($LASTEXITCODE -ne 0) {
    throw "Clone failed. Create the Space first at https://huggingface.co/new-space (SDK: Docker, Public)."
}

# Copy backend files — exclude secrets, caches and local runtime state
robocopy . $tmp /E /XD __pycache__ venv .venv .git /XF .env *.pyc *.log history.db deploy_to_hf.ps1 | Out-Null

Push-Location $tmp
try {
    git config user.name $HfUser
    git config user.email "$HfUser@users.noreply.huggingface.co"
    git add -A
    # dvago_products.txt is gitignored locally but wanted in the image (warm price index)
    git add -f scrapers/dvago_products.txt 2>$null
    git commit -m "MedPak AI backend deploy"
    git push
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Push failed — when prompted: username = $HfUser, password = HF write token." -ForegroundColor Yellow
        Write-Host "Retry manually:  cd $tmp ;  git push"
        exit 1
    }
} finally {
    Pop-Location
}

Remove-Item -Recurse -Force $tmp

Write-Host ""
Write-Host "Deployed! First build takes ~10-20 min (installs PyTorch + EasyOCR)." -ForegroundColor Green
Write-Host "  Space:  $spaceUrl"
Write-Host "  API:    $appUrl/api/health"
Write-Host ""
Write-Host "Next: add these secrets in Space Settings -> Variables and secrets:" -ForegroundColor Cyan
Write-Host "  GROQ_API_KEY = gsk_...      (https://console.groq.com/keys)"
Write-Host "  SECRET_KEY   = <long random string>"
Write-Host "  CORS_ORIGINS = [`"*`"]"
Write-Host "  DEBUG        = false"
