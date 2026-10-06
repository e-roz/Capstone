<#
.SYNOPSIS
    Builds the guard PC installer and publishes it as a GitHub release.

.DESCRIPTION
    Every guard PC from 1.2.0 on watches these releases and installs a newer
    one by itself, when its gates are quiet (SiteUpdater.cs). Publishing is
    therefore the moment an update goes out to every guard post: test the
    installer on this PC first.

        powershell -ExecutionPolicy Bypass -File site-server\installer\publish-release.ps1 -Version 1.2.0

    Needs everything build-installer.ps1 needs, plus the GitHub CLI (gh),
    signed in to an account that can publish releases on e-roz/Capstone.

    Use -SkipBuild to publish an installer already in output\.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$Here = $PSScriptRoot
$Tag = "site-installer-v$Version"
$Exe = Join-Path $Here "output\AimParkSetup-$Version.exe"
$Sum = "$Exe.sha256"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw "The GitHub CLI (gh) isn't installed." }

# "release not found" on stderr is the answer hoped for, but Windows
# PowerShell 5.1 turns a native command's stderr into a terminating error
# under "Stop", so the check runs under "Continue".
$ErrorActionPreference = "Continue"
gh release view $Tag --repo e-roz/Capstone 2>$null | Out-Null
$exists = $LASTEXITCODE -eq 0
$ErrorActionPreference = "Stop"
if ($exists) { throw "Release $Tag already exists. Pick a higher version." }

if (-not $SkipBuild) {
    & (Join-Path $Here "build-installer.ps1") -Version $Version
}
if (-not (Test-Path $Exe)) { throw "$Exe not found." }

# The guard PC refuses a download that doesn't match this.
$hash = (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($Sum, "$hash  AimParkSetup-$Version.exe`n")

Write-Host "`nAbout to publish $Tag. Every guard PC on an older version will install it." -ForegroundColor Yellow
$answer = Read-Host "Type the version again to confirm"
if ($answer -ne $Version) { throw "Not published." }

# Tag the commit this installer was built from (it must be pushed already).
$commit = (git rev-parse HEAD).Trim()
# gh reports upload progress on stderr: judged by its exit code, as above.
$ErrorActionPreference = "Continue"
gh release create $Tag $Exe $Sum --repo e-roz/Capstone --target $commit `
    --title "Guard PC installer $Version" `
    --notes "Guard PCs on 1.2.0 or later install this by themselves when the gates are quiet. A new guard PC: download AimParkSetup-$Version.exe and run it."
if ($LASTEXITCODE -ne 0) { throw "gh release create failed." }

Write-Host "`nPublished $Tag." -ForegroundColor Green
