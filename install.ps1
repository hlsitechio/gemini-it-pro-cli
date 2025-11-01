<#
.SYNOPSIS
    Gemini IT Pro CLI Installer
    One-line installation: irm https://raw.githubusercontent.com/your-repo/gemini-it-pro-cli/main/install.ps1 | iex

.DESCRIPTION
    Installs or updates the Gemini IT Pro CLI with cloud-powered AI assistant backed by Supabase.
    Handles dependencies, environment setup, and PATH configuration automatically.

.NOTES
    Version: 1.0.0
    Author: Hubert (rainkode)
    License: MIT
#>

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# CLI Configuration
$CLI_NAME = "itprocli"
$CLI_DISPLAY_NAME = "Gemini IT Pro CLI"
$INSTALL_DIR = "$env:LOCALAPPDATA\$CLI_NAME"
$LAUNCHER_NAME = "$CLI_NAME.ps1"
$WRAPPER_NAME = "itprocli-cloud.ps1"
$REPO_URL = "https://github.com/your-repo/gemini-it-pro-cli" # Update with your actual repo
$GITHUB_RAW = "https://raw.githubusercontent.com/your-repo/gemini-it-pro-cli/main"

# Colors
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Failure { Write-Host "✗ $args" -ForegroundColor Red }

# Banner
function Show-Banner {
    Write-Host ""
    Write-Host "╔═════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                             ║" -ForegroundColor Cyan
    Write-Host "║   " -NoNewline -ForegroundColor Cyan
    Write-Host "Gemini IT Pro CLI Installer" -NoNewline -ForegroundColor White
    Write-Host "            ║" -ForegroundColor Cyan
    Write-Host "║                                             ║" -ForegroundColor Cyan
    Write-Host "║   " -NoNewline -ForegroundColor Cyan
    Write-Host "Cloud-Powered AI Assistant" -NoNewline -ForegroundColor Magenta
    Write-Host "             ║" -ForegroundColor Cyan
    Write-Host "║                                             ║" -ForegroundColor Cyan
    Write-Host "╚═════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check PowerShell version
function Test-PowerShellVersion {
    Write-Info "Checking PowerShell version..."
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Failure "PowerShell 7 or higher is required."
        Write-Info "Current version: $($PSVersionTable.PSVersion)"
        Write-Info "Install PowerShell 7+: https://aka.ms/powershell"
        return $false
    }
    Write-Success "PowerShell $($PSVersionTable.PSVersion) detected"
    return $true
}

# Check Node.js/npm installation
function Test-NodeEnvironment {
    Write-Info "Checking Node.js environment..."
    
    $nodeVersion = $null
    $npmVersion = $null
    
    try {
        $nodeVersion = node --version 2>$null
        $npmVersion = npm --version 2>$null
    }
    catch {
        Write-Warning "Node.js not found in PATH"
    }
    
    if (-not $nodeVersion) {
        Write-Warning "Node.js not detected. MCP servers require Node.js 18+"
        Write-Info "Install Node.js from: https://nodejs.org/"
        $response = Read-Host "Continue without Node.js? (MCP features will be limited) [Y/n]"
        if ($response -eq 'n') {
            return $false
        }
    }
    else {
        Write-Success "Node.js $nodeVersion detected"
        Write-Success "npm $npmVersion detected"
    }
    
    return $true
}

# Create installation directory
function New-InstallDirectory {
    Write-Info "Creating installation directory: $INSTALL_DIR"
    
    if (Test-Path $INSTALL_DIR) {
        Write-Info "Installation directory already exists"
        $response = Read-Host "Overwrite existing installation? [Y/n]"
        if ($response -eq 'n') {
            Write-Info "Installation cancelled"
            return $false
        }
        Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    Write-Success "Installation directory created"
    return $true
}

# Download CLI files from GitHub
function Get-CLIFiles {
    Write-Info "Downloading CLI files..."
    
    $files = @(
        "itprocli-cloud.ps1",
        "GeminiCLI.ps1",
        "MCPDiagnostics.ps1",
        "mcp_config.json",
        ".env.local.example"
    )
    
    foreach ($file in $files) {
        try {
            $url = "$GITHUB_RAW/$file"
            $dest = Join-Path $INSTALL_DIR $file
            
            Write-Host "  Downloading $file..." -NoNewline
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
            Write-Host " ✓" -ForegroundColor Green
        }
        catch {
            Write-Host " ✗" -ForegroundColor Red
            Write-Warning "Failed to download $file: $_"
        }
    }
    
    Write-Success "CLI files downloaded"
    return $true
}

# Copy local files if running from local installation
function Copy-LocalFiles {
    Write-Info "Copying CLI files from local installation..."
    
    $files = @(
        "itprocli-cloud.ps1",
        "GeminiCLI.ps1",
        "MCPDiagnostics.ps1",
        "mcp_config.json"
    )
    
    foreach ($file in $files) {
        $source = Join-Path $PSScriptRoot $file
        $dest = Join-Path $INSTALL_DIR $file
        
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination $dest -Force
            Write-Success "Copied $file"
        }
        else {
            Write-Warning "File not found: $file"
        }
    }
    
    # Copy .env.local if it exists
    $envSource = Join-Path $PSScriptRoot ".env.local"
    $envDest = Join-Path $INSTALL_DIR ".env.local"
    if (Test-Path $envSource) {
        Copy-Item -Path $envSource -Destination $envDest -Force
        Write-Success "Copied .env.local (API keys)"
    }
    else {
        Write-Info "No .env.local found - you'll need to configure API keys manually"
    }
    
    return $true
}

# Create launcher script
function New-LauncherScript {
    Write-Info "Creating launcher script..."
    
    $launcherPath = Join-Path $INSTALL_DIR $LAUNCHER_NAME
    
    $launcherContent = @"
#!/usr/bin/env pwsh
# Gemini IT Pro CLI Launcher
# This script launches the cloud-powered CLI wrapper

`$ErrorActionPreference = 'Stop'
`$CLI_DIR = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$WRAPPER_SCRIPT = Join-Path `$CLI_DIR 'itprocli-cloud.ps1'

if (-not (Test-Path `$WRAPPER_SCRIPT)) {
    Write-Error "CLI wrapper not found: `$WRAPPER_SCRIPT"
    exit 1
}

# Launch the cloud CLI wrapper
& `$WRAPPER_SCRIPT `@args
"@
    
    Set-Content -Path $launcherPath -Value $launcherContent -Force
    Write-Success "Launcher script created: $LAUNCHER_NAME"
    return $true
}

# Add CLI to PATH
function Add-ToPath {
    Write-Info "Adding CLI to PATH..."
    
    $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    
    if ($currentPath -like "*$INSTALL_DIR*") {
        Write-Info "CLI already in PATH"
        return $true
    }
    
    $newPath = "$currentPath;$INSTALL_DIR"
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    
    # Update current session PATH
    $env:PATH = "$env:PATH;$INSTALL_DIR"
    
    Write-Success "CLI added to PATH"
    Write-Warning "You may need to restart your terminal for PATH changes to take effect"
    return $true
}

# Setup environment configuration
function Initialize-Environment {
    Write-Info "Setting up environment configuration..."
    
    $envPath = Join-Path $INSTALL_DIR ".env.local"
    
    if (Test-Path $envPath) {
        Write-Info ".env.local already exists"
        return $true
    }
    
    Write-Info "Creating .env.local template..."
    
    $envTemplate = @"
# Gemini API Configuration
GEMINI_API_KEY=your_gemini_api_key_here

# Supabase Configuration
SUPABASE_FUNCTION_URL=https://your-project.supabase.co/functions/v1/gemini-it-pro
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
SUPABASE_PROJECT_REF=your_project_ref_here

# CLI Configuration
CLI_USER_ID=user_001
CLI_MAX_TOKENS=8000
"@
    
    Set-Content -Path $envPath -Value $envTemplate -Force
    Write-Success "Environment template created"
    Write-Warning "Please edit .env.local with your actual API keys and configuration"
    Write-Info "Location: $envPath"
    
    return $true
}

# Verify installation
function Test-Installation {
    Write-Info "Verifying installation..."
    
    $wrapperPath = Join-Path $INSTALL_DIR $WRAPPER_NAME
    $launcherPath = Join-Path $INSTALL_DIR $LAUNCHER_NAME
    $envPath = Join-Path $INSTALL_DIR ".env.local"
    
    $allGood = $true
    
    if (Test-Path $wrapperPath) {
        Write-Success "CLI wrapper found"
    }
    else {
        Write-Failure "CLI wrapper missing"
        $allGood = $false
    }
    
    if (Test-Path $launcherPath) {
        Write-Success "Launcher script found"
    }
    else {
        Write-Failure "Launcher script missing"
        $allGood = $false
    }
    
    if (Test-Path $envPath) {
        Write-Success "Environment configuration found"
    }
    else {
        Write-Warning "Environment configuration missing (optional)"
    }
    
    return $allGood
}

# Show post-installation instructions
function Show-PostInstallation {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Configure your API keys:" -ForegroundColor White
    Write-Host "     Edit: " -NoNewline -ForegroundColor Gray
    Write-Host "$INSTALL_DIR\.env.local" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Launch the CLI:" -ForegroundColor White
    Write-Host "     Run: " -NoNewline -ForegroundColor Gray
    Write-Host "$CLI_NAME" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  3. Get help:" -ForegroundColor White
    Write-Host "     Type: " -NoNewline -ForegroundColor Gray
    Write-Host ":help" -ForegroundColor Yellow -NoNewline
    Write-Host " in the CLI" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Documentation: " -NoNewline -ForegroundColor Gray
    Write-Host "$REPO_URL" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
}

# Main installation flow
function Install-GeminiCLI {
    Show-Banner
    
    # Pre-flight checks
    if (-not (Test-PowerShellVersion)) {
        exit 1
    }
    
    if (-not (Test-NodeEnvironment)) {
        exit 1
    }
    
    # Installation steps
    if (-not (New-InstallDirectory)) {
        exit 1
    }
    
    # Try local copy first, fallback to GitHub download
    if (Test-Path (Join-Path $PSScriptRoot "itprocli-cloud.ps1")) {
        Write-Info "Installing from local files..."
        Copy-LocalFiles
    }
    else {
        Write-Info "Installing from GitHub..."
        Get-CLIFiles
    }
    
    New-LauncherScript
    Add-ToPath
    Initialize-Environment
    
    # Post-installation
    if (Test-Installation) {
        Show-PostInstallation
    }
    else {
        Write-Failure "Installation verification failed"
        Write-Info "Please check the installation directory: $INSTALL_DIR"
        exit 1
    }
}

# Run installation
try {
    Install-GeminiCLI
}
catch {
    Write-Failure "Installation failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}