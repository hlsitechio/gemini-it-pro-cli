# MCP (Model Context Protocol) Client for PowerShell
# Manages MCP server processes and handles JSON-RPC communication

class MCPServer {
    [string]$Name
    [System.Diagnostics.Process]$Process
    [System.IO.StreamWriter]$StdinWriter
    [System.IO.StreamReader]$StdoutReader
    [hashtable]$Tools = @{}
    [int]$MessageId = 0

    MCPServer([string]$name, [string]$command, [array]$args, [hashtable]$env) {
        $this.Name = $name
        $this.Start($command, $args, $env)
    }

    [void]Start([string]$command, [array]$args, [hashtable]$env) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $command
        $psi.Arguments = $args -join ' '
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        # Add environment variables
        if ($env) {
            foreach ($key in $env.Keys) {
                $psi.EnvironmentVariables[$key] = $env[$key]
            }
        }

        $this.Process = [System.Diagnostics.Process]::Start($psi)
        $this.StdinWriter = $this.Process.StandardInput
        $this.StdoutReader = $this.Process.StandardOutput

        # Initialize MCP connection
        $this.Initialize()
    }

    [void]Initialize() {
        # Send initialize request
        $initRequest = @{
            jsonrpc = '2.0'
            id = $this.MessageId++
            method = 'initialize'
            params = @{
                protocolVersion = '2024-11-05'
                clientInfo = @{
                    name = 'gemini-it-pro-cli'
                    version = '1.0.0'
                }
                capabilities = @{}
            }
        } | ConvertTo-Json -Depth 10 -Compress

        $this.StdinWriter.WriteLine($initRequest)
        $this.StdinWriter.Flush()

        # Read response
        $response = $this.StdoutReader.ReadLine() | ConvertFrom-Json

        # List tools
        $this.ListTools()
    }

    [void]ListTools() {
        $request = @{
            jsonrpc = '2.0'
            id = $this.MessageId++
            method = 'tools/list'
            params = @{}
        } | ConvertTo-Json -Depth 10 -Compress

        $this.StdinWriter.WriteLine($request)
        $this.StdinWriter.Flush()

        $response = $this.StdoutReader.ReadLine() | ConvertFrom-Json
        
        if ($response.result.tools) {
            foreach ($tool in $response.result.tools) {
                $this.Tools[$tool.name] = $tool
            }
        }
    }

    [object]CallTool([string]$toolName, [hashtable]$arguments) {
        $request = @{
            jsonrpc = '2.0'
            id = $this.MessageId++
            method = 'tools/call'
            params = @{
                name = $toolName
                arguments = $arguments
            }
        } | ConvertTo-Json -Depth 10 -Compress

        $this.StdinWriter.WriteLine($request)
        $this.StdinWriter.Flush()

        $response = $this.StdoutReader.ReadLine() | ConvertFrom-Json
        return $response.result
    }

    [void]Stop() {
        if ($this.Process -and !$this.Process.HasExited) {
            $this.Process.Kill()
        }
    }
}

function Initialize-MCPServers {
    param([string]$ConfigPath = "$PSScriptRoot\mcp_config.json")

    $script:MCPServers = @{}

    if (!(Test-Path $ConfigPath)) {
        Write-Warning "MCP config not found: $ConfigPath"
        return
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    foreach ($serverName in $config.mcpServers.PSObject.Properties.Name) {
        $serverConfig = $config.mcpServers.$serverName
        
        try {
            Write-Host "Starting MCP server: $serverName..." -ForegroundColor Cyan
            $server = [MCPServer]::new(
                $serverName,
                $serverConfig.command,
                $serverConfig.args,
                $serverConfig.env
            )
            $script:MCPServers[$serverName] = $server
            Write-Host "✓ $serverName ready with $($server.Tools.Count) tools" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to start MCP server $serverName`: $_"
        }
    }
}

function Get-MCPTools {
    $allTools = @()
    foreach ($serverName in $script:MCPServers.Keys) {
        $server = $script:MCPServers[$serverName]
        foreach ($toolName in $server.Tools.Keys) {
            $tool = $server.Tools[$toolName]
            $allTools += @{
                serverName = $serverName
                toolName = $toolName
                tool = $tool
            }
        }
    }
    return $allTools
}

function Invoke-MCPTool {
    param(
        [string]$ServerName,
        [string]$ToolName,
        [hashtable]$Arguments
    )

    if (!$script:MCPServers.ContainsKey($ServerName)) {
        throw "MCP server not found: $ServerName"
    }

    $server = $script:MCPServers[$ServerName]
    return $server.CallTool($ToolName, $Arguments)
}

function Stop-MCPServers {
    foreach ($server in $script:MCPServers.Values) {
        $server.Stop()
    }
}

Export-ModuleMember -Function Initialize-MCPServers, Get-MCPTools, Invoke-MCPTool, Stop-MCPServers
