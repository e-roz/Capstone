<#
.SYNOPSIS
    Removes the AimPark site server service and its firewall rule.
    Leaves the local database and the built files alone.

    Run as administrator:
        powershell -ExecutionPolicy Bypass -File C:\AimPark\site-server\uninstall-service.ps1
#>
param([int]$Port = 5041)

$ErrorActionPreference = "Stop"
$ServiceName = "AimParkSite"

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($service) {
    if ($service.Status -ne "Stopped") { Stop-Service -Name $ServiceName -Force }
    sc.exe delete $ServiceName | Out-Null
    Write-Host "Removed the '$ServiceName' service."
}
else {
    Write-Host "No '$ServiceName' service is installed."
}

Get-NetFirewallRule -DisplayName "AimPark Site Server ($Port)" -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule
