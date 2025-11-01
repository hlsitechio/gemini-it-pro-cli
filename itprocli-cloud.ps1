#requires -Version 7.0

param(
  [string]$FunctionUrl = $env:SUPABASE_FUNCTION_URL,
  [string]$ApiKey = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$UserId = $env:ITPROCLI_USER_ID
)

$ErrorActionPreference = 'Stop'

# Config directory for local settings (no secrets stored by default)
$cfgDir = Join-Path $env:APPDATA 'GeminiItProCLI'
$cfgPath = Join-Path $cfgDir 'config.json'
if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir | Out-Null }

# Load or initialize config (persist userId only)
$cfg = @{}
if (Test-Path $cfgPath) {
  try { $cfg = Get-Content -Raw -Path $cfgPath | ConvertFrom-Json } catch { $cfg = @{} }
}
if (-not $UserId) {
  if ($cfg.userId) { $UserId = [string]$cfg.userId } else { $UserId = [guid]::NewGuid().Guid }
}
if (-not $FunctionUrl) {
  if ($cfg.functionUrl) { $FunctionUrl = [string]$cfg.functionUrl }
}

# Validate required settings
if (-not $FunctionUrl) {
  Write-Host "Missing SUPABASE_FUNCTION_URL. Set env var or pass -FunctionUrl." -ForegroundColor Yellow
  exit 2
}
if (-not $ApiKey) {
  Write-Host "Missing SUPABASE_ANON_KEY. Set env var or pass -ApiKey." -ForegroundColor Yellow
  exit 3
}

# Persist non-secret config
$cfg.userId = $UserId
$cfg.functionUrl = $FunctionUrl
$cfg | ConvertTo-Json -Depth 5 | Set-Content -Path $cfgPath -Encoding UTF8

# Conversation state
$history = @()

function Invoke-EdgeFunction {
  param(
    [Parameter(Mandatory=$true)][string]$Message
  )
  $body = [ordered]@{
    message = $Message
    history = $history
    userId  = $UserId
  } | ConvertTo-Json -Depth 10

  $headers = @{
    'Authorization' = "Bearer $ApiKey"
    'apikey'        = $ApiKey
    'Content-Type'  = 'application/json'
  }

  try {
    $resp = Invoke-RestMethod -Method POST -Uri $FunctionUrl -Headers $headers -Body $body -TimeoutSec 120
    return $resp
  } catch {
    $err = $_
    $msg = if ($err.ErrorDetails.Message) { $err.ErrorDetails.Message } else { $err.Exception.Message }
    Write-Host "Edge Function call failed: $msg" -ForegroundColor Red
    return $null
  }
}

function Show-Help {
  Write-Host "Commands:" -ForegroundColor Cyan
  Write-Host ":help    Show this help"
  Write-Host ":reset   Clear conversation history"
  Write-Host ":history Show message count"
  Write-Host ":config  Show current config (keys are not displayed)"
  Write-Host ":exit    Quit"
}

Write-Host "Gemini IT Pro (Cloud) — connected to Supabase Edge Function" -ForegroundColor Cyan
Write-Host "Type :help for commands."

try {
  while ($true) {
    $inputMsg = Read-Host -Prompt 'You'
    if ([string]::IsNullOrWhiteSpace($inputMsg)) { continue }

    switch -Regex ($inputMsg) {
      '^:exit$'    { break }
      '^:help$'    { Show-Help; continue }
      '^:reset$'   { $history = @(); Write-Host "History cleared." -ForegroundColor Yellow; continue }
      '^:history$' { Write-Host ("History entries: {0}" -f $history.Count); continue }
      '^:config$'  {
        Write-Host ("Function URL: {0}" -f $FunctionUrl)
        Write-Host ("User ID:      {0}" -f $UserId)
        Write-Host "SUPABASE_ANON_KEY: **** (hidden)"
        continue
      }
    }

    # Send message
    $requestHistory = $history
    $resp = Invoke-EdgeFunction -Message $inputMsg
    if (-not $resp) { continue }

    # Update history from server (authoritative)
    if ($resp.history) { $history = @($resp.history) }

    if ($resp.response) {
      Write-Host ''
      Write-Host 'AI:' -ForegroundColor Green
      Write-Host ($resp.response) -ForegroundColor White
      Write-Host ''
    } elseif ($resp.error) {
      Write-Host ("Error: {0}" -f $resp.error) -ForegroundColor Red
    } else {
      Write-Host "No response payload from function." -ForegroundColor Yellow
    }
  }
}
catch {
  Write-Host ("Fatal: {0}" -f $_.Exception.Message) -ForegroundColor Red
}
