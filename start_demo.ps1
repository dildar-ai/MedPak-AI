# MedPak AI — self-hosted demo launcher
# ─────────────────────────────────────────────────────────────────────────────
# Starts the backend (which also serves the built frontend) and tunnels it
# through ngrok so friends can test the app from anywhere.
#
# One-time setup (email signup, no credit card):
#   1. Create a free account:       https://dashboard.ngrok.com/signup
#   2. Install ngrok:               winget install ngrok.ngrok
#   3. Add your auth token:         ngrok config add-authtoken <YOUR_TOKEN>
#      (token shown at https://dashboard.ngrok.com/get-started/your-authtoken)
#   4. Claim your free static URL:  https://dashboard.ngrok.com/domains
#   5. Paste it into $NgrokDomain below, then run this script:
#      powershell -ExecutionPolicy Bypass -File .\start_demo.ps1
#
# While testing: keep this PC on and awake (friends hit your machine).
# Stop the demo: close the ngrok window and the backend window.

$NgrokDomain = "PASTE_YOUR_STATIC_DOMAIN_HERE"   # e.g. "calm-badger-123.ngrok-free.app"

$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$backend = Join-Path $root "backend"

# ── Sanity checks ────────────────────────────────────────────────────────────
if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
    throw "ngrok is not installed. Run:  winget install ngrok.ngrok   (then reopen this window)"
}
if ($NgrokDomain -eq "PASTE_YOUR_STATIC_DOMAIN_HERE") {
    throw "Set your free static domain in `$NgrokDomain at the top of this script (claim it at https://dashboard.ngrok.com/domains)"
}
ngrok config check | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "ngrok has no auth token yet. Run:  ngrok config add-authtoken <YOUR_TOKEN>"
}

# ── Start the backend (API + frontend build) unless it is already running ────
if (Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue) {
    Write-Host ">> Backend already running on port 8000 — reusing it." -ForegroundColor Yellow
} else {
    Write-Host ">> Starting backend (API + frontend) in a new window..." -ForegroundColor Green
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$backend'; python main.py"
}

Write-Host ">> Waiting for the API..." -ForegroundColor Green
$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    try { Invoke-RestMethod "http://127.0.0.1:8000/api/health/" -TimeoutSec 2 | Out-Null; $ready = $true; break } catch { }
}
if (-not $ready) { throw "Backend did not come up — check its window for errors." }

# ── Start the tunnel with your fixed public URL ──────────────────────────────
Write-Host ">> Starting ngrok tunnel to $NgrokDomain ..." -ForegroundColor Green
Start-Process ngrok -ArgumentList "http", "8000", "--domain=$NgrokDomain"

$publicUrl = $null
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    try {
        $tunnels   = (Invoke-RestMethod "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2).tunnels
        $publicUrl = ($tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1).public_url
        if ($publicUrl) { break }
    } catch { }
}
if (-not $publicUrl) { throw "Tunnel did not come up — check the ngrok window (wrong domain? no internet?)." }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  MedPak AI is LIVE — share this link with your testers:"    -ForegroundColor Cyan
Write-Host "  $publicUrl"                                                -ForegroundColor Yellow
Write-Host "  Local copy: http://127.0.0.1:8000"                         -ForegroundColor Cyan
Write-Host "  Keep this PC on. Close the ngrok window to stop."          -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Start-Process $publicUrl
