[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackageDirectory,
    [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'EkkoStudio-Windows-Notes'),
    [string]$Node = 'node.exe',
    [ValidateRange(1024, 65535)]
    [int]$Port = 8648
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path Env:AUTH_TOKEN)) {
    throw 'Set AUTH_TOKEN for this local instance before starting Ekko Studio.'
}
$app = (Resolve-Path -LiteralPath $PackageDirectory).Path
$entry = Join-Path $app 'dist/server/index.js'
$manifest = Get-Content -Raw -LiteralPath (Join-Path $app 'package.json') | ConvertFrom-Json
if ($manifest.name -ne 'hermes-web-ui' -or $manifest.version -ne '0.7.21' -or
    -not (Test-Path -LiteralPath $entry -PathType Leaf)) {
    throw 'Expected the installed hermes-web-ui 0.7.21 package directory.'
}
$nodeExe = (Get-Command $Node -CommandType Application).Source
$root = [IO.Path]::GetFullPath($DataDirectory)
$studio = Join-Path $root 'studio'
$hermes = Join-Path $root 'hermes'
$workspace = Join-Path $hermes 'workspace'
$baseUrl = "http://127.0.0.1:$Port"
if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) {
    throw "Port $Port is already in use. Stop the previous instance or choose another -Port."
}
foreach ($directory in @($root, $studio, $hermes, $workspace)) {
    [void][IO.Directory]::CreateDirectory($directory)
}
$childEnvironment = @{
    NODE_ENV = 'production'
    PORT = "$Port"
    BIND_HOST = '127.0.0.1'
    HERMES_WEB_UI_HOME = $studio
    HERMES_HOME = $hermes
    HERMES_AGENT_BASE_HOME = $hermes
    WORKSPACE_BASE = $workspace
    HERMES_LAN_DISCOVERY_ENABLED = '0'
    HERMES_WEB_UI_DISABLE_GATEWAY_AUTOSTART = '1'
    HERMES_WEB_UI_DISABLE_MCP_AUTOINJECT = '1'
    HERMES_WEB_UI_DISABLE_SKILL_INJECTION = '1'
}
$previous = @{}
try {
    foreach ($name in $childEnvironment.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $childEnvironment[$name], 'Process')
    }
    $launch = @{
        FilePath = $nodeExe
        ArgumentList = ('"' + $entry + '"')
        WorkingDirectory = $app
        WindowStyle = 'Hidden'
        RedirectStandardOutput = Join-Path $root 'server.stdout.log'
        RedirectStandardError = Join-Path $root 'server.stderr.log'
        PassThru = $true
    }
    $server = Start-Process @launch
} finally {
    foreach ($name in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}
$deadline = [DateTime]::UtcNow.AddSeconds(75)
do {
    if ($server.HasExited) { throw "Ekko Studio exited with code $($server.ExitCode). Check server.stderr.log." }
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/health/ready" -TimeoutSec 2
        if ($response.status -eq 'ready') {
            Write-Output "Ekko Studio is ready at $baseUrl/ (PID $($server.Id))"
            return
        }
    } catch {}
    Start-Sleep -Milliseconds 500
} while ([DateTime]::UtcNow -lt $deadline)
throw "Ekko Studio did not become ready within 75 seconds (PID $($server.Id)). Check server.stderr.log."
