<#
.SYNOPSIS
    Installs the AimPark site server on the guard PC as a Windows service
    that starts when the PC turns on and restarts itself if it crashes.

.DESCRIPTION
    Run once, and again after pulling new code (it updates in place).
    Right-click PowerShell -> "Run as administrator", then:

        powershell -ExecutionPolicy Bypass -File C:\AimPark\site-server\install-service.ps1

    Before running it, finish steps 1-8 of SITE_SERVER.md: the local
    database exists and has its tables, and appsettings.Site.json is filled in.
#>
param(
    # Where the built server is kept. Not the source folder, so pulling new
    # code never touches the running copy until this script is run again.
    [string]$InstallDir = "C:\AimPark\site-server-app",
    [int]$Port = 5041
)

$ErrorActionPreference = "Stop"
$ServiceName = "AimParkSite"
$Project = Join-Path $PSScriptRoot "..\AimPark.API\AimPark.API\AimPark.API.csproj"
$SourceSettings = Join-Path $PSScriptRoot "..\AimPark.API\AimPark.API\appsettings.Site.json"

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# --- Checks -----------------------------------------------------------------

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Run this from PowerShell opened with 'Run as administrator'." }

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "The .NET 8 SDK is not installed. See SITE_SERVER.md step 1."
}

if (-not (Test-Path $SourceSettings)) {
    throw "Missing $SourceSettings. Copy appsettings.Site.example.json to appsettings.Site.json and fill it in first (SITE_SERVER.md step 5)."
}

# --- Build ------------------------------------------------------------------

$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing -and $existing.Status -ne "Stopped") {
    Step "Stopping the running server so its files can be replaced"
    Stop-Service -Name $ServiceName -Force
}

Step "Building the server into $InstallDir"
dotnet publish $Project -c Release -o $InstallDir --nologo
if ($LASTEXITCODE -ne 0) { throw "Build failed. See the errors above." }

# The build copies appsettings.Site.json along with the rest, but copy it
# explicitly so a settings change is picked up even when nothing else changed.
Copy-Item $SourceSettings (Join-Path $InstallDir "appsettings.Site.json") -Force

# --- Service ----------------------------------------------------------------

$exe = Join-Path $InstallDir "AimPark.API.exe"
$binPath = "`"$exe`" --environment Site --urls http://0.0.0.0:$Port"

# Start after PostgreSQL, so the first thing the server does isn't failing
# to reach its own database.
$postgres = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $existing) {
    Step "Installing the '$ServiceName' service (starts with Windows)"
    New-Service -Name $ServiceName `
        -BinaryPathName $binPath `
        -DisplayName "AimPark Site Server" `
        -Description "Makes gate decisions for AimPark at the guard post and syncs with the cloud." `
        -StartupType Automatic | Out-Null
}
else {
    Step "Updating the '$ServiceName' service"
    sc.exe config $ServiceName binPath= $binPath start= auto | Out-Null
}

if ($postgres) {
    sc.exe config $ServiceName depend= $($postgres.Name) | Out-Null
    Write-Host "    Starts after $($postgres.Name)."
}
else {
    Write-Warning "No PostgreSQL service found. The server will retry until the database is up."
}

# Restart 5 seconds after a crash, every time.
sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null

# --- Firewall ---------------------------------------------------------------

# Private networks only: the school LAN, never public Wi-Fi.
$ruleName = "AimPark Site Server ($Port)"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    Step "Allowing gate readers on the school network to reach port $Port"
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP `
        -LocalPort $Port -Action Allow -Profile Private | Out-Null
}

# --- Start and check --------------------------------------------------------

Step "Starting the server"
Start-Service -Name $ServiceName

$statusUrl = "http://localhost:$Port/api/site/status"
$status = $null
for ($i = 0; $i -lt 15 -and -not $status; $i++) {
    Start-Sleep -Seconds 2
    try { $status = Invoke-RestMethod $statusUrl -TimeoutSec 3 } catch { }
}

if (-not $status) {
    throw "The service started but isn't answering on $statusUrl. Check Event Viewer -> Windows Logs -> Application for 'AimParkSite'."
}

Write-Host "`nThe site server is running and will start by itself when the PC turns on." -ForegroundColor Green
Write-Host "Status: $statusUrl"
$status | Format-List
if (-not $status.cloudConnected) {
    Write-Host "Not connected to the cloud yet. That's normal for the first few seconds; open the status page again shortly." -ForegroundColor Yellow
}
