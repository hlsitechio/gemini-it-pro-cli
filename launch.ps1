# Gemini IT Pro CLI Launcher
# This script launches the CLI application

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "Starting Gemini IT Pro CLI..." -ForegroundColor Cyan

# Check if .env.local exists and has a valid API key
$envFile = Join-Path $ScriptDir ".env.local"
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match "GEMINI_API_KEY=PLACEHOLDER_API_KEY" -or $envContent -match "GEMINI_API_KEY=\s*$") {
        Write-Host ""
        Write-Host "⚠️  API Key Required" -ForegroundColor Yellow
        Write-Host "Please enter your Gemini API key:" -ForegroundColor Yellow
        $apiKey = Read-Host -AsSecureString
        $apiKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiKey))
        Set-Content $envFile "GEMINI_API_KEY=$apiKeyPlain"
        Write-Host "✓ API key saved" -ForegroundColor Green
        Write-Host ""
    }
}

# Ensure Node.js and npm are in PATH
$nodePath = "C:\Program Files\nodejs"
$npmPath = "$env:APPDATA\npm"
if ($env:PATH -notlike "*$nodePath*") {
    $env:PATH = "$nodePath;$env:PATH"
}
if ($env:PATH -notlike "*$npmPath*") {
    $env:PATH = "$npmPath;$env:PATH"
}

# Check if node_modules exists
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    & "$env:APPDATA\npm\npm.ps1" install
}

# Start the dev server
Write-Host "Launching application..." -ForegroundColor Cyan
Start-Process "http://localhost:3000" -ErrorAction SilentlyContinue

# Run the dev server (this will keep the window open)
& "$env:APPDATA\npm\npm.ps1" run dev
