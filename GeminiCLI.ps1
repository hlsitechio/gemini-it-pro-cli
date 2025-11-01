# Gemini IT Pro CLI - Native PowerShell Version
# A true command-line AI assistant for IT professionals with local tool execution

param(
    [string]$ApiKey = $env:GEMINI_API_KEY
)

$ErrorActionPreference = "Stop"

# Configuration
$script:GEMINI_API_KEY = $ApiKey
$script:GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent"
$script:conversationHistory = @()  # stores full content objects, not just text
$script:MEMORY_FILE = "$PSScriptRoot\memory_store.json"
$script:MCP_CONFIG_FILE = "$PSScriptRoot\mcp_config.json"
$script:MCPServers = @{}
$script:MCPTools = @()

# Load memory on startup
if (Test-Path $script:MEMORY_FILE) {
    $script:MemoryStore = Get-Content $script:MEMORY_FILE -Raw | ConvertFrom-Json -AsHashtable
} else {
    $script:MemoryStore = @{}
}

# MCP Server Class
class MCPServer {
    [string]$Name
    [System.Diagnostics.Process]$Process
    [System.IO.StreamWriter]$StdinWriter
    [System.IO.StreamReader]$StdoutReader
    [hashtable]$Tools = @{}
    [int]$MessageId = 0

    MCPServer([string]$name, [string]$command, [array]$args, $env) {
        $this.Name = $name
        $this.Start($command, $args, $env)
    }

    [void]Start([string]$command, [array]$args, $env) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        
        # Resolve npx path on Windows
        if ($command -eq 'npx') {
            $npxPath = "$env:APPDATA\npm\npx.cmd"
            if (Test-Path $npxPath) {
                $command = $npxPath
            }
        }
        
        $psi.FileName = $command
        $psi.Arguments = $args -join ' '
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        if ($env) {
            if ($env -is [hashtable]) {
                foreach ($key in $env.Keys) {
                    $psi.EnvironmentVariables[$key] = $env[$key]
                }
            } else {
                foreach ($prop in $env.PSObject.Properties) {
                    $psi.EnvironmentVariables[$prop.Name] = $prop.Value
                }
            }
        }

        $this.Process = [System.Diagnostics.Process]::Start($psi)
        $this.StdinWriter = $this.Process.StandardInput
        $this.StdoutReader = $this.Process.StandardOutput
        
        # Consume stderr in background to prevent blocking
        $this.Process.BeginErrorReadLine()
        
        # Wait for process to be ready and skip startup messages
        Start-Sleep -Milliseconds 1500
        
        if ($this.Process.HasExited) {
            throw "Process exited immediately with code $($this.Process.ExitCode)"
        }
        
        # Skip any non-JSON startup messages
        while ($this.StdoutReader.Peek() -ge 0) {
            $line = $this.StdoutReader.ReadLine()
            # If it looks like JSON-RPC, we've hit the real output
            if ($line -match '^\s*\{.*"jsonrpc"') {
                # This was actual JSON-RPC, we'll need to handle it
                break
            }
            # Otherwise skip startup messages
        }

        $this.Initialize()
    }

    [void]Initialize() {
        try {
            if (!$this.StdinWriter.BaseStream.CanWrite) {
                throw "Stdin stream not writable"
            }
            
            $initRequest = @{
                jsonrpc = '2.0'
                id = $this.MessageId++
                method = 'initialize'
                params = @{
                    protocolVersion = '2024-11-05'
                    clientInfo = @{ name = 'gemini-it-pro-cli'; version = '1.0.0' }
                    capabilities = @{}
                }
            } | ConvertTo-Json -Depth 10 -Compress

            $this.StdinWriter.WriteLine($initRequest)
            $this.StdinWriter.Flush()
            
            # Wait for response with timeout
            $timeout = 5000
            $startTime = Get-Date
            while (((Get-Date) - $startTime).TotalMilliseconds -lt $timeout) {
                if ($this.StdoutReader.Peek() -ge 0) {
                    $responseLine = $this.StdoutReader.ReadLine()
                    if ($responseLine) {
                        $response = $responseLine | ConvertFrom-Json
                        $this.ListTools()
                        return
                    }
                }
                Start-Sleep -Milliseconds 100
            }
            throw "No response within timeout"
        } catch {
            throw "Initialization failed: $_"
        }
    }

    [void]ListTools() {
        try {
            $request = @{
                jsonrpc = '2.0'
                id = $this.MessageId++
                method = 'tools/list'
                params = @{}
            } | ConvertTo-Json -Depth 10 -Compress

            $this.StdinWriter.WriteLine($request)
            $this.StdinWriter.Flush()
            
            $responseLine = $this.StdoutReader.ReadLine()
            if ($responseLine) {
                $response = $responseLine | ConvertFrom-Json
                if ($response.result.tools) {
                    foreach ($tool in $response.result.tools) {
                        $this.Tools[$tool.name] = $tool
                    }
                }
            }
        } catch {
            throw "ListTools failed: $_"
        }
    }

    [object]CallTool([string]$toolName, [hashtable]$arguments) {
        $request = @{
            jsonrpc = '2.0'
            id = $this.MessageId++
            method = 'tools/call'
            params = @{ name = $toolName; arguments = $arguments }
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
    if (!(Test-Path $script:MCP_CONFIG_FILE)) { return }
    
    # Ensure Node.js and npm are in PATH
    $nodePath = "C:\Program Files\nodejs"
    $npmPath = "$env:APPDATA\npm"
    if ($env:PATH -notlike "*$nodePath*") {
        $env:PATH = "$nodePath;$env:PATH"
    }
    if ($env:PATH -notlike "*$npmPath*") {
        $env:PATH = "$npmPath;$env:PATH"
    }
    
    $config = Get-Content $script:MCP_CONFIG_FILE -Raw | ConvertFrom-Json
    Write-Host "Starting MCP servers..." -ForegroundColor Cyan

    foreach ($serverName in $config.mcpServers.PSObject.Properties.Name) {
        $serverConfig = $config.mcpServers.$serverName
        try {
            Write-Host "  Connecting to $serverName..." -ForegroundColor Gray -NoNewline
            
            # Run in background job with timeout
            $job = Start-Job -ScriptBlock {
                param($name, $cmd, $args, $env)
                try {
                    $server = [MCPServer]::new($name, $cmd, $args, $env)
                    return $server
                } catch {
                    return $null
                }
            } -ArgumentList $serverName, $serverConfig.command, $serverConfig.args, $serverConfig.env
            
            # Wait max 10 seconds
            $result = Wait-Job $job -Timeout 10 | Receive-Job
            Remove-Job $job -Force -ErrorAction SilentlyContinue
            
            if ($result) {
                $script:MCPServers[$serverName] = $result
                foreach ($toolName in $result.Tools.Keys) {
                    $tool = $result.Tools[$toolName]
                    $script:MCPTools += @{
                        name = "mcp_$($serverName)_$toolName"
                        description = "[MCP:$serverName] $($tool.description)"
                        serverName = $serverName
                        toolName = $toolName
                        schema = $tool.inputSchema
                    }
                }
                Write-Host " ✓ ($($result.Tools.Count) tools)" -ForegroundColor Green
            } else {
                Write-Host " ✗ timeout" -ForegroundColor Yellow
            }
        } catch {
            Write-Host " ✗ failed" -ForegroundColor Red
        }
    }
}

function Invoke-MCPTool {
    param([string]$ServerName, [string]$ToolName, [hashtable]$Arguments)
    $server = $script:MCPServers[$ServerName]
    $result = $server.CallTool($ToolName, $Arguments)
    
    if ($result.content) {
        $output = ($result.content | ForEach-Object { $_.text }) -join "`n"
        return [pscustomobject]@{ display = $output; raw = $output }
    }
    return [pscustomobject]@{ display = "MCP tool executed"; raw = ($result | ConvertTo-Json -Depth 5) }
}

# Colors
$script:Colors = @{
    Prompt = "Cyan"
    User = "White"
    AI = "Green"
    Error = "Red"
    Warning = "Yellow"
    System = "Gray"
}

# Tool declarations for Gemini function calling
$script:FunctionDeclarations = @(
    @{ name = 'scan_virus'; description = 'Runs a Windows Defender quick scan.'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'get_network_config'; description = 'Shows detailed IP configuration for all adapters.'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'get_system_info'; description = 'Shows hardware and OS details.'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'check_disk_health'; description = 'Checks C: drive health (read-only).'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'get_running_processes'; description = 'Lists running processes.'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'get_system_services'; description = 'Lists Windows services and status.'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'test_network_connection'; description = 'Tests connectivity to a host and port.'; parameters = @{ type = 'OBJECT'; properties = @{ computerName = @{ type = 'STRING' }; port = @{ type = 'INTEGER' } }; required = @('computerName') }},
    @{ name = 'install_ps_module'; description = 'Installs a PowerShell module for current user.'; parameters = @{ type = 'OBJECT'; properties = @{ moduleName = @{ type = 'STRING' } }; required = @('moduleName') }},
    @{ name = 'search_web'; description = 'Search the internet using DuckDuckGo for information, tools, or solutions.'; parameters = @{ type = 'OBJECT'; properties = @{ query = @{ type = 'STRING'; description = 'Search query' }; maxResults = @{ type = 'INTEGER'; description = 'Max results (default 5)' } }; required = @('query') }},
    @{ name = 'fetch_url_content'; description = 'Fetch and parse content from a webpage URL.'; parameters = @{ type = 'OBJECT'; properties = @{ url = @{ type = 'STRING'; description = 'URL to fetch' } }; required = @('url') }},
    @{ name = 'read_file'; description = 'Read contents of a file.'; parameters = @{ type = 'OBJECT'; properties = @{ path = @{ type = 'STRING'; description = 'Absolute file path' } }; required = @('path') }},
    @{ name = 'write_file'; description = 'Write or create a file with content.'; parameters = @{ type = 'OBJECT'; properties = @{ path = @{ type = 'STRING'; description = 'Absolute file path' }; content = @{ type = 'STRING'; description = 'File content' } }; required = @('path', 'content') }},
    @{ name = 'list_directory'; description = 'List files and folders in a directory.'; parameters = @{ type = 'OBJECT'; properties = @{ path = @{ type = 'STRING'; description = 'Directory path' } }; required = @('path') }},
    @{ name = 'delete_file'; description = 'Delete a file.'; parameters = @{ type = 'OBJECT'; properties = @{ path = @{ type = 'STRING'; description = 'Absolute file path' } }; required = @('path') }},
    @{ name = 'memory_store'; description = 'Store information in persistent memory for later retrieval.'; parameters = @{ type = 'OBJECT'; properties = @{ key = @{ type = 'STRING'; description = 'Memory key/identifier' }; value = @{ type = 'STRING'; description = 'Information to store' } }; required = @('key', 'value') }},
    @{ name = 'memory_retrieve'; description = 'Retrieve previously stored information from memory.'; parameters = @{ type = 'OBJECT'; properties = @{ key = @{ type = 'STRING'; description = 'Memory key to retrieve' } }; required = @('key') }},
    @{ name = 'memory_list'; description = 'List all stored memory keys.'; parameters = @{ type = 'OBJECT'; properties = @{}; required = @() }},
    @{ name = 'memory_delete'; description = 'Delete a memory entry.'; parameters = @{ type = 'OBJECT'; properties = @{ key = @{ type = 'STRING'; description = 'Memory key to delete' } }; required = @('key') }}
)

# ===================== Local tool implementations =====================
function Invoke-ToolScanVirus {
    try {
        if (Get-Command Start-MpScan -ErrorAction SilentlyContinue) {
            # Quick scan is safe and fast; may require Defender
            Start-MpScan -ScanType QuickScan | Out-Null
            $msg = 'Windows Defender quick scan started.'
        } else {
            $msg = 'Windows Defender module not available. Simulated scan started.'
        }
        return [pscustomobject]@{ display = $msg; raw = $msg }
    } catch {
        return [pscustomobject]@{ display = "Failed to start scan: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolGetNetworkConfig {
    try {
        if (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
            $out = Get-NetIPConfiguration | Format-List | Out-String
        } else {
            $out = ipconfig /all | Out-String
        }
        return [pscustomobject]@{ display = $out.Trim(); raw = $out }
    } catch { return [pscustomobject]@{ display = $_.ToString(); raw = $_.ToString() } }
}

function Invoke-ToolGetSystemInfo {
    try {
        if (Get-Command Get-ComputerInfo -ErrorAction SilentlyContinue) {
            $out = (Get-ComputerInfo | Select-Object CsName, OsName, OsVersion, OsBuildNumber, WindowsProductName, CsManufacturer, CsModel, CsNumberOfLogicalProcessors, CsTotalPhysicalMemory | Format-List | Out-String)
        } else { $out = systeminfo | Out-String }
        return [pscustomobject]@{ display = $out.Trim(); raw = $out }
    } catch { return [pscustomobject]@{ display = $_.ToString(); raw = $_.ToString() } }
}

function Invoke-ToolCheckDiskHealth {
    try {
        $vol = Get-Volume -DriveLetter C -ErrorAction Stop | Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, SizeRemaining, Size
        $pd = Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object FriendlyName, HealthStatus, OperationalStatus | Format-Table | Out-String
        $out = ($vol | Format-List | Out-String) + "`nPhysicalDisk:`n" + $pd
        return [pscustomobject]@{ display = $out.Trim(); raw = $out }
    } catch { return [pscustomobject]@{ display = $_.ToString(); raw = $_.ToString() } }
}

function Invoke-ToolGetRunningProcesses {
    try {
        $out = (Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 20 Id, ProcessName, CPU, WorkingSet | Format-Table -AutoSize | Out-String)
        return [pscustomobject]@{ display = $out.Trim(); raw = $out }
    } catch { return [pscustomobject]@{ display = $_.ToString(); raw = $_.ToString() } }
}

function Invoke-ToolGetSystemServices {
    try {
        $out = (Get-Service | Sort-Object Status, DisplayName | Select-Object Status, Name, DisplayName | Format-Table -AutoSize | Out-String)
        return [pscustomobject]@{ display = $out.Trim(); raw = $out }
    } catch { return [pscustomobject]@{ display = $_.ToString(); raw = $_.ToString() } }
}

function Invoke-ToolTestNetworkConnection {
    param([string]$computerName, [int]$port = 80)
    try {
        if (Get-Command Test-NetConnection -ErrorAction SilentlyContinue) {
            $t = Test-NetConnection -ComputerName $computerName -Port $port
            $out = $t | Select-Object ComputerName, RemoteAddress, InterfaceAlias, SourceAddress, PingSucceeded, TcpTestSucceeded | Format-List | Out-String
        } else {
            $ping = Test-Connection -ComputerName $computerName -Count 1 -Quiet
            $out = "PingSucceeded: $ping`nTcpTestSucceeded: (unknown - Test-NetConnection not available)"
        }
        return [pscustomobject]@{ display = $out.Trim(); raw = $out }
    } catch { return [pscustomobject]@{ display = $_.ToString(); raw = $_.ToString() } }
}

function Invoke-ToolInstallPsModule {
    param([string]$moduleName)
    try {
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nuget) { Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction SilentlyContinue | Out-Null }
        Install-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
        $out = "Module '$moduleName' installed for CurrentUser."
        return [pscustomobject]@{ display = $out; raw = $out }
    } catch { return [pscustomobject]@{ display = "Failed to install module: $_"; raw = $_.ToString() } }
}

function Invoke-ToolSearchWeb {
    param([string]$query, [int]$maxResults = 5)
    try {
        $encodedQuery = [System.Web.HttpUtility]::UrlEncode($query)
        $url = "https://html.duckduckgo.com/html/?q=$encodedQuery"
        $response = Invoke-WebRequest -Uri $url -UserAgent 'Mozilla/5.0' -UseBasicParsing
        
        # Parse results
        $results = @()
        $matches = [regex]::Matches($response.Content, '<a[^>]+class="[^"]*result__a[^"]*"[^>]+href="([^"]+)"[^>]*>([^<]+)</a>')
        
        foreach ($match in $matches | Select-Object -First $maxResults) {
            $rawUrl = $match.Groups[1].Value
            $title = $match.Groups[2].Value
            
            # Extract actual URL from DuckDuckGo redirect
            if ($rawUrl -match 'uddg=([^&]+)') {
                $cleanUrl = [System.Web.HttpUtility]::UrlDecode($matches[1])
            } else {
                $cleanUrl = $rawUrl
            }
            
            $results += "$($results.Count + 1). $title`n   $cleanUrl`n"
        }
        
        if ($results.Count -eq 0) {
            $out = "No results found for: $query"
        } else {
            $out = "Search results for '$query':`n`n" + ($results -join "")
        }
        
        return [pscustomobject]@{ display = $out; raw = $out }
    } catch { 
        return [pscustomobject]@{ display = "Search failed: $_"; raw = $_.ToString() } 
    }
}

function Invoke-ToolFetchUrlContent {
    param([string]$url)
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        $content = $response.Content
        
        # Basic HTML stripping
        $content = $content -replace '<script[^>]*>.*?</script>', ''
        $content = $content -replace '<style[^>]*>.*?</style>', ''
        $content = $content -replace '<[^>]+>', ' '
        $content = $content -replace '\\s+', ' '
        $content = $content.Trim()
        
        # Limit to first 2000 chars
        if ($content.Length -gt 2000) {
            $content = $content.Substring(0, 2000) + '...'
        }
        
        $out = "Content from $url`:`n$content"
        return [pscustomobject]@{ display = $out; raw = $content }
    } catch {
        return [pscustomobject]@{ display = "Failed to fetch URL: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolReadFile {
    param([string]$path)
    try {
        if (Test-Path $path -PathType Leaf) {
            $content = Get-Content -Path $path -Raw -ErrorAction Stop
            $out = "File: $path`n`n$content"
            return [pscustomobject]@{ display = $out; raw = $content }
        } else {
            return [pscustomobject]@{ display = "File not found: $path"; raw = "File not found" }
        }
    } catch {
        return [pscustomobject]@{ display = "Failed to read file: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolWriteFile {
    param([string]$path, [string]$content)
    try {
        Set-Content -Path $path -Value $content -ErrorAction Stop
        $out = "File created/updated: $path"
        return [pscustomobject]@{ display = $out; raw = $out }
    } catch {
        return [pscustomobject]@{ display = "Failed to write file: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolListDirectory {
    param([string]$path)
    try {
        if (Test-Path $path -PathType Container) {
            $items = Get-ChildItem -Path $path -ErrorAction Stop | Select-Object Mode, LastWriteTime, Length, Name
            $out = ($items | Format-Table -AutoSize | Out-String)
            return [pscustomobject]@{ display = "Directory: $path`n`n$out"; raw = $out }
        } else {
            return [pscustomobject]@{ display = "Directory not found: $path"; raw = "Directory not found" }
        }
    } catch {
        return [pscustomobject]@{ display = "Failed to list directory: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolDeleteFile {
    param([string]$path)
    try {
        if (Test-Path $path) {
            Remove-Item -Path $path -Force -ErrorAction Stop
            $out = "File deleted: $path"
            return [pscustomobject]@{ display = $out; raw = $out }
        } else {
            return [pscustomobject]@{ display = "File not found: $path"; raw = "File not found" }
        }
    } catch {
        return [pscustomobject]@{ display = "Failed to delete file: $_"; raw = $_.ToString() }
    }
}

function Save-MemoryStore {
    $script:MemoryStore | ConvertTo-Json -Depth 10 | Set-Content $script:MEMORY_FILE
}

function Invoke-ToolMemoryStore {
    param([string]$key, [string]$value)
    try {
        $script:MemoryStore[$key] = @{
            value = $value
            timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        Save-MemoryStore
        $out = "Stored in memory: $key"
        return [pscustomobject]@{ display = $out; raw = $out }
    } catch {
        return [pscustomobject]@{ display = "Failed to store memory: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolMemoryRetrieve {
    param([string]$key)
    try {
        if ($script:MemoryStore.ContainsKey($key)) {
            $entry = $script:MemoryStore[$key]
            $out = "Memory [$key] (stored $($entry.timestamp)):`n$($entry.value)"
            return [pscustomobject]@{ display = $out; raw = $entry.value }
        } else {
            return [pscustomobject]@{ display = "No memory found for key: $key"; raw = "Not found" }
        }
    } catch {
        return [pscustomobject]@{ display = "Failed to retrieve memory: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolMemoryList {
    try {
        if ($script:MemoryStore.Count -eq 0) {
            return [pscustomobject]@{ display = "Memory is empty."; raw = "Empty" }
        }
        $list = @()
        foreach ($key in $script:MemoryStore.Keys) {
            $entry = $script:MemoryStore[$key]
            $list += "• $key (stored $($entry.timestamp))"
        }
        $out = "Stored memories:`n" + ($list -join "`n")
        return [pscustomobject]@{ display = $out; raw = $out }
    } catch {
        return [pscustomobject]@{ display = "Failed to list memory: $_"; raw = $_.ToString() }
    }
}

function Invoke-ToolMemoryDelete {
    param([string]$key)
    try {
        if ($script:MemoryStore.ContainsKey($key)) {
            $script:MemoryStore.Remove($key)
            Save-MemoryStore
            $out = "Deleted from memory: $key"
            return [pscustomobject]@{ display = $out; raw = $out }
        } else {
            return [pscustomobject]@{ display = "No memory found for key: $key"; raw = "Not found" }
        }
    } catch {
        return [pscustomobject]@{ display = "Failed to delete memory: $_"; raw = $_.ToString() }
    }
}

function Invoke-LocalTool {
    param($functionCall)
    $name = $functionCall.name
    $args = $functionCall.args
    switch ($name) {
        'scan_virus' { return Invoke-ToolScanVirus }
        'get_network_config' { return Invoke-ToolGetNetworkConfig }
        'get_system_info' { return Invoke-ToolGetSystemInfo }
        'check_disk_health' { return Invoke-ToolCheckDiskHealth }
        'get_running_processes' { return Invoke-ToolGetRunningProcesses }
        'get_system_services' { return Invoke-ToolGetSystemServices }
        'test_network_connection' { 
            $port = if ($args.port) { [int]$args.port } else { 80 }
            return Invoke-ToolTestNetworkConnection -computerName $args.computerName -port $port 
        }
        'install_ps_module' { return Invoke-ToolInstallPsModule -moduleName $args.moduleName }
        'search_web' {
            $max = if ($args.maxResults) { [int]$args.maxResults } else { 5 }
            return Invoke-ToolSearchWeb -query $args.query -maxResults $max
        }
        'fetch_url_content' { return Invoke-ToolFetchUrlContent -url $args.url }
        'read_file' { return Invoke-ToolReadFile -path $args.path }
        'write_file' { return Invoke-ToolWriteFile -path $args.path -content $args.content }
        'list_directory' { return Invoke-ToolListDirectory -path $args.path }
        'delete_file' { return Invoke-ToolDeleteFile -path $args.path }
        'memory_store' { return Invoke-ToolMemoryStore -key $args.key -value $args.value }
        'memory_retrieve' { return Invoke-ToolMemoryRetrieve -key $args.key }
        'memory_list' { return Invoke-ToolMemoryList }
        'memory_delete' { return Invoke-ToolMemoryDelete -key $args.key }
        default {
            # Check if it's an MCP tool
            if ($name -match '^mcp_(.+)_(.+)$') {
                $serverName = $matches[1]
                $toolName = $matches[2]
                return Invoke-MCPTool -ServerName $serverName -ToolName $toolName -Arguments $args
            }
            return [pscustomobject]@{ display = "Unknown tool '$name'"; raw = "Unknown tool '$name'" }
        }
    }
}

function Show-Welcome {
    Clear-Host
    Write-Host ""
    Write-Host "   ______                           ___ ___" -ForegroundColor Cyan
    Write-Host "  / ____/___   ____   ____ ___     /   |   |" -ForegroundColor Cyan
    Write-Host " / / __ / _ \\ / __ \\ / __ \`__ \\   / /| |   |" -ForegroundColor Cyan
    Write-Host "/ /_/ //  __// /_/ // / / / / /  / / | |   |" -ForegroundColor Cyan
    Write-Host "\\____/ \\___/ \\____//_/ /_/ /_/  /_/  |_|___|" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Gemini IT Pro CLI - PowerShell Edition" -ForegroundColor White
    Write-Host "(c) 2025 - AI-Powered IT Assistant" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  Type your question or command naturally" -ForegroundColor White
    Write-Host "  'help' - Show available commands" -ForegroundColor White
    Write-Host "  'clear' - Clear screen" -ForegroundColor White
    Write-Host "  'exit' or 'quit' - Exit CLI" -ForegroundColor White
    Write-Host ""
}

function Invoke-GeminiAPI {
    param(
        [array]$Contents
    )
    if (-not $script:GEMINI_API_KEY) { throw "API Key not found." }

    $systemInstruction = @"
You are an expert, conversational IT support agent for Windows 11 named 'Gemini IT Pro'.
Your audience is professional IT administrators.
Your goal is to help users solve problems through a step-by-step diagnostic process. Act as a "copilot".

**Memory System:**
You have persistent memory across sessions. Use it to:
- Store user preferences, names, and important information (memory_store)
- Recall previously stored information (memory_retrieve)
- Check what you remember (memory_list)
- When you see a memory exists (from memory_list), IMMEDIATELY retrieve it with memory_retrieve
- When a user introduces themselves or shares personal info, ALWAYS store it in memory
- Before saying you don't know something about the user, check memory first
- NEVER just list memories - always retrieve and tell the user what's stored

**Your Workflow:**
1. The user will describe a problem or ask a question.
2. If asked about user information (name, preferences, etc.), check memory_list or memory_retrieve first.
3. If you have a tool that can gather relevant data, **call that function**.
4. The output of that tool will be sent back to you in the next turn.
5. **You MUST analyze the tool's output** in the context of the original problem.
6. Based on your analysis, provide a concise explanation and **ask a follow-up question** to suggest the next logical step.

**Crucially, do not just call another tool immediately after the first one. Always analyze, respond with your findings, and wait for the user's confirmation before proceeding.**

**Available tools:**
- scan_virus: Windows Defender scan
- get_network_config: IP configuration for all adapters
- get_system_info: Hardware and OS details
- check_disk_health: C: drive health check
- get_running_processes: Active processes list
- get_system_services: Windows services status
- test_network_connection: Test connectivity to host/port
- install_ps_module: Install PowerShell module
- search_web: Search the internet for tools, solutions, or information
- fetch_url_content: Retrieve content from a specific URL
- read_file: Read file contents
- write_file: Create or update a file with content
- list_directory: List files and folders in a directory
- delete_file: Delete a file
- memory_store: Store information persistently across sessions
- memory_retrieve: Retrieve stored information
- memory_list: List all stored memories
- memory_delete: Delete a memory entry

**Communication style:**
- Be direct, technical, and professional
- Use IT terminology appropriately
- Provide actionable insights
- Ask diagnostic questions when needed
"@

    $body = @{
        contents = $Contents
        systemInstruction = @{ parts = @(@{ text = $systemInstruction }) }
        tools = @(@{ functionDeclarations = $script:FunctionDeclarations })
        generationConfig = @{ temperature = 0.3; maxOutputTokens = 1024 }
    } | ConvertTo-Json -Depth 20

    $url = "$script:GEMINI_API_URL`?key=$script:GEMINI_API_KEY"
    return Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType 'application/json'
}

function Show-Help {
    Write-Host ""
    Write-Host "=== Gemini IT Pro CLI - Help ===" -ForegroundColor Cyan
    Write-Host "AI-callable tools:" -ForegroundColor Yellow
    Write-Host "  scan_virus, get_network_config, get_system_info, check_disk_health" -ForegroundColor Gray
    Write-Host "  get_running_processes, get_system_services, test_network_connection, install_ps_module" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Built-in commands: help, clear, exit" -ForegroundColor White
}

function Start-GeminiCLI {
    Show-Welcome
    
    # Initialize MCP servers
    Initialize-MCPServers
    
    if (-not $script:GEMINI_API_KEY) {
        Write-Host "⚠️  API Key Required" -ForegroundColor Yellow
        $key = Read-Host -Prompt "Enter your Gemini API key" -AsSecureString
        $script:GEMINI_API_KEY = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key))
        Write-Host ""
    }

    # conversation history as 'contents' objects
    $history = @()

    while ($true) {
        Write-Host ""
        Write-Host "You" -ForegroundColor $script:Colors.Prompt -NoNewline; Write-Host "> " -NoNewline
        $userInput = Read-Host
        if ([string]::IsNullOrWhiteSpace($userInput)) { continue }

        switch ($userInput.ToLower().Trim()) {
            'exit' { Write-Host 'Goodbye!' -ForegroundColor Cyan; return }
            'quit' { Write-Host 'Goodbye!' -ForegroundColor Cyan; return }
            'clear' { Show-Welcome; continue }
            'help' { Show-Help; continue }
        }

        $history += @{ role='user'; parts=@(@{ text = $userInput }) }

        # First turn: ask Gemini (may request a tool)
        Write-Host "Gemini> Thinking..." -ForegroundColor Gray
        $resp = Invoke-GeminiAPI -Contents $history

        $parts = $resp.candidates[0].content.parts
        $textParts = @($parts | Where-Object { $_.text })
        $funcParts = @($parts | Where-Object { $_.functionCall })

        if ($textParts.Count -gt 0) {
            foreach ($tp in $textParts) { Write-Host $tp.text -ForegroundColor $script:Colors.AI }
        }

        if ($funcParts.Count -gt 0) {
            $fc = $funcParts[0].functionCall
            # Add model functionCall to history
            $history += @{ role='model'; parts=@(@{ functionCall = $fc }) }

            # Execute locally
            $toolResult = Invoke-LocalTool -functionCall $fc
            Write-Host ""; Write-Host $toolResult.display -ForegroundColor White

            # Provide tool response back for analysis
            $history += @{ role='user'; parts=@(@{ functionResponse = @{ name = $fc.name; response = @{ content = $toolResult.raw } } }) }

            # Ask Gemini to analyze
            $analysis = Invoke-GeminiAPI -Contents $history
            $analysisParts = $analysis.candidates[0].content.parts
            foreach ($p in $analysisParts) {
                if ($p.text) { Write-Host $p.text -ForegroundColor $script:Colors.AI }
            }

            # Add model analysis to history
            $history += $analysis.candidates[0].content

            # Trim history
            if ($history.Count -gt 30) { $history = $history[-30..-1] }
        } else {
            # Add model text to history
            $history += $resp.candidates[0].content
            if ($history.Count -gt 30) { $history = $history[-30..-1] }
        }
    }
}

# Start the CLI
Start-GeminiCLI
