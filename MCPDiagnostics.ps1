# MCP Diagnostics and Logging Module
# Provides comprehensive logging and error handling for MCP server operations

param(
    [string]$LogPath = "$PSScriptRoot\logs"
)

$ErrorActionPreference = "Stop"

# Ensure log directory exists
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$script:MCPLogFile = Join-Path $LogPath "mcp_$(Get-Date -Format 'yyyyMMdd').log"
$script:DiagnosticMode = $true

function Write-MCPLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [string]$ServerName = '',
        
        [switch]$Console
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $serverTag = if ($ServerName) { "[$ServerName]" } else { "" }
    $logLine = "$timestamp [$Level] $serverTag $Message"
    
    # Always write to file
    Add-Content -Path $script:MCPLogFile -Value $logLine -Encoding UTF8
    
    # Optionally write to console
    if ($Console -or $script:DiagnosticMode) {
        $color = switch ($Level) {
            'ERROR' { 'Red' }
            'WARN' { 'Yellow' }
            'DEBUG' { 'DarkGray' }
            default { 'Gray' }
        }
        Write-Host $logLine -ForegroundColor $color
    }
}

function Test-MCPEnvironment {
    Write-MCPLog "Starting MCP environment diagnostics" -Level INFO -Console
    
    $diagnostics = @{
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        NodeInstalled = $false
        NodeVersion = $null
        NpmInstalled = $false
        NpmVersion = $null
        NpxInstalled = $false
        NpxPath = $null
        Errors = @()
    }
    
    # Check Node.js
    try {
        $nodeVersion = node --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $diagnostics.NodeInstalled = $true
            $diagnostics.NodeVersion = $nodeVersion
            Write-MCPLog "Node.js detected: $nodeVersion" -Level INFO -Console
        }
    } catch {
        $diagnostics.Errors += "Node.js not found in PATH"
        Write-MCPLog "Node.js not detected" -Level WARN -Console
    }
    
    # Check npm
    try {
        $npmVersion = npm --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $diagnostics.NpmInstalled = $true
            $diagnostics.NpmVersion = $npmVersion
            Write-MCPLog "npm detected: $npmVersion" -Level INFO -Console
        }
    } catch {
        $diagnostics.Errors += "npm not found in PATH"
        Write-MCPLog "npm not detected" -Level WARN -Console
    }
    
    # Check npx
    $npxPaths = @(
        "$env:APPDATA\npm\npx.cmd",
        "C:\Program Files\nodejs\npx.cmd",
        "$env:ProgramFiles\nodejs\npx.cmd"
    )
    
    foreach ($path in $npxPaths) {
        if (Test-Path $path) {
            $diagnostics.NpxInstalled = $true
            $diagnostics.NpxPath = $path
            Write-MCPLog "npx found at: $path" -Level INFO -Console
            break
        }
    }
    
    if (!$diagnostics.NpxInstalled) {
        $diagnostics.Errors += "npx not found in standard locations"
        Write-MCPLog "npx not detected" -Level WARN -Console
    }
    
    # Check if MCP packages are installed globally
    try {
        $globalPackages = npm list -g --depth=0 2>&1 | Out-String
        if ($globalPackages -match '@modelcontextprotocol') {
            Write-MCPLog "MCP packages detected globally" -Level INFO -Console
        } else {
            Write-MCPLog "No MCP packages found globally - npx will download on first use" -Level INFO -Console
        }
    } catch {
        Write-MCPLog "Could not check global npm packages" -Level DEBUG
    }
    
    return $diagnostics
}

function Start-MCPProcessMonitor {
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,
        
        [Parameter(Mandatory)]
        [string]$ServerName,
        
        [scriptblock]$OnStdout = {},
        [scriptblock]$OnStderr = {},
        [scriptblock]$OnExit = {}
    )
    
    Write-MCPLog "Starting process monitor" -ServerName $ServerName -Level DEBUG
    
    # Monitor stdout
    $stdoutEvent = Register-ObjectEvent -InputObject $Process -EventName OutputDataReceived -Action {
        $data = $Event.SourceEventArgs.Data
        if ($data) {
            $serverName = $Event.MessageData.ServerName
            Write-MCPLog "STDOUT: $data" -ServerName $serverName -Level DEBUG
            if ($Event.MessageData.OnStdout) {
                & $Event.MessageData.OnStdout $data
            }
        }
    } -MessageData @{ ServerName = $ServerName; OnStdout = $OnStdout }
    
    # Monitor stderr
    $stderrEvent = Register-ObjectEvent -InputObject $Process -EventName ErrorDataReceived -Action {
        $data = $Event.SourceEventArgs.Data
        if ($data) {
            $serverName = $Event.MessageData.ServerName
            Write-MCPLog "STDERR: $data" -ServerName $serverName -Level WARN
            if ($Event.MessageData.OnStderr) {
                & $Event.MessageData.OnStderr $data
            }
        }
    } -MessageData @{ ServerName = $ServerName; OnStderr = $OnStderr }
    
    # Monitor exit
    $exitEvent = Register-ObjectEvent -InputObject $Process -EventName Exited -Action {
        $serverName = $Event.MessageData.ServerName
        $exitCode = $Event.Sender.ExitCode
        Write-MCPLog "Process exited with code $exitCode" -ServerName $serverName -Level WARN
        if ($Event.MessageData.OnExit) {
            & $Event.MessageData.OnExit $exitCode
        }
    } -MessageData @{ ServerName = $ServerName; OnExit = $OnExit }
    
    $Process.BeginOutputReadLine()
    $Process.BeginErrorReadLine()
    
    return @{
        StdoutEvent = $stdoutEvent
        StderrEvent = $stderrEvent
        ExitEvent = $exitEvent
    }
}

function Stop-MCPProcessMonitor {
    param($EventHandlers)
    
    if ($EventHandlers) {
        if ($EventHandlers.StdoutEvent) { Unregister-Event -SourceIdentifier $EventHandlers.StdoutEvent.Name -ErrorAction SilentlyContinue }
        if ($EventHandlers.StderrEvent) { Unregister-Event -SourceIdentifier $EventHandlers.StderrEvent.Name -ErrorAction SilentlyContinue }
        if ($EventHandlers.ExitEvent) { Unregister-Event -SourceIdentifier $EventHandlers.ExitEvent.Name -ErrorAction SilentlyContinue }
    }
}

function Test-MCPServerHealth {
    param(
        [Parameter(Mandatory)]
        [string]$ServerName,
        
        [Parameter(Mandatory)]
        $Server
    )
    
    $health = @{
        IsRunning = $false
        ProcessId = $null
        HasExited = $true
        CanWrite = $false
        CanRead = $false
        ToolsLoaded = 0
        Errors = @()
    }
    
    try {
        if ($Server.Process) {
            $health.ProcessId = $Server.Process.Id
            $health.HasExited = $Server.Process.HasExited
            $health.IsRunning = !$Server.Process.HasExited
            
            if ($Server.StdinWriter) {
                $health.CanWrite = $Server.StdinWriter.BaseStream.CanWrite
            }
            
            if ($Server.StdoutReader) {
                $health.CanRead = !$Server.StdoutReader.EndOfStream
            }
            
            if ($Server.Tools) {
                $health.ToolsLoaded = $Server.Tools.Count
            }
        } else {
            $health.Errors += "No process object"
        }
    } catch {
        $health.Errors += $_.Exception.Message
        Write-MCPLog "Health check failed: $_" -ServerName $ServerName -Level ERROR
    }
    
    return $health
}

function Export-MCPDiagnostics {
    param(
        [string]$OutputPath = "$PSScriptRoot\logs\mcp_diagnostics_$(Get-Date -Format 'yyyyMMddHHmmss').json"
    )
    
    $diagnostics = @{
        Timestamp = Get-Date -Format 'o'
        Environment = Test-MCPEnvironment
        Logs = if (Test-Path $script:MCPLogFile) { Get-Content $script:MCPLogFile -Tail 100 } else { @() }
    }
    
    $diagnostics | ConvertTo-Json -Depth 10 | Set-Content $OutputPath
    Write-MCPLog "Diagnostics exported to: $OutputPath" -Level INFO -Console
    return $OutputPath
}

# Export functions
Export-ModuleMember -Function @(
    'Write-MCPLog',
    'Test-MCPEnvironment',
    'Start-MCPProcessMonitor',
    'Stop-MCPProcessMonitor',
    'Test-MCPServerHealth',
    'Export-MCPDiagnostics'
)
