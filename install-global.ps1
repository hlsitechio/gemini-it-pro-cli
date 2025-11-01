# IT Pro CLI - Global Installation Script
# Adds 'itprocli' command to your PATH

#Requires -Version 7.0

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IT Pro CLI - Global Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$InstallPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Get current user PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")

# Check if already in PATH
if ($UserPath -like "*$InstallPath*") {
    Write-Host "✓ Already in PATH" -ForegroundColor Green
} else {
    Write-Host "Adding to PATH..." -ForegroundColor Yellow
    
    # Add to PATH
    $NewPath = "$UserPath;$InstallPath"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    
    # Update current session
    $env:Path = "$env:Path;$InstallPath"
    
    Write-Host "✓ Added to PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run:" -ForegroundColor Yellow
Write-Host "  itprocli" -ForegroundColor White
Write-Host ""
Write-Host "From any directory!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: You may need to restart your terminal" -ForegroundColor Gray
Write-Host "      for the PATH changes to take effect." -ForegroundColor Gray
Write-Host ""

$test = Read-Host "Launch now? (Y/n)"
if ($test -ne "n" -and $test -ne "N") {
    & "$InstallPath\itprocli.ps1"
}
