#!/usr/bin/env pwsh
# IT Pro CLI Global Launcher
# Usage: itprocli

$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Ensure Node.js is in PATH
$nodePath = "C:\Program Files\nodejs"
$npmPath = "$env:APPDATA\npm"
if (Test-Path $nodePath) {
    if ($env:PATH -notlike "*$nodePath*") {
        $env:PATH = "$nodePath;$env:PATH"
    }
}
if (Test-Path $npmPath) {
    if ($env:PATH -notlike "*$npmPath*") {
        $env:PATH = "$npmPath;$env:PATH"
    }
}

# Set API key from environment
$env:GEMINI_API_KEY = "AIzaSyBJ0MT3q-ro7JaXcWsll3C8SF0mbwSIois"

# Launch the CLI
& "$ScriptDir\GeminiCLI.ps1"
