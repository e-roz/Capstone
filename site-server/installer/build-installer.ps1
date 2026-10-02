<#
.SYNOPSIS
    Builds AimParkSetup-<version>.exe, the guard PC installer.

.DESCRIPTION
    Run on the developer PC (never on the guard PC):

        powershell -ExecutionPolicy Bypass -File site-server\installer\build-installer.ps1 -Version 1.0.0

    Needs: .NET 8 SDK, Flutter, Inno Setup 6. Downloads the PostgreSQL
    installer into downloads\ the first time (~370 MB).

    Includes the ALPR camera app when alpr-service\dist\AimParkALPR exists;
    otherwise the installer is built without it.

    Output: site-server\installer\output\AimParkSetup-<version>.exe
#>
param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$Here = $PSScriptRoot
$Repo = (Resolve-Path (Join-Path $Here "..\..")).Path
$Build = Join-Path $Here "build"
$Server = Join-Path $Build "server"

$PgVersion = "17.10-1"
$PgFile = Join-Path $Here "downloads\postgresql-$PgVersion-windows-x64.exe"
$PgUrl = "https://get.enterprisedb.com/postgresql/postgresql-$PgVersion-windows-x64.exe"

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# --- Tools -------------------------------------------------------------------

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup 6 isn't installed. Get it from https://jrsoftware.org/isdl.php" }
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw "The .NET 8 SDK isn't installed." }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw "Flutter isn't on PATH." }

if (Test-Path $Build) { Remove-Item $Build -Recurse -Force }
New-Item -ItemType Directory -Path $Build | Out-Null

# --- Server --------------------------------------------------------------------

Step "Publishing the server (self-contained: the guard PC needs no .NET install)"
dotnet publish (Join-Path $Repo "AimPark.API\AimPark.API\AimPark.API.csproj") `
    -c Release -r win-x64 --self-contained true -p:Version=$Version -o $Server --nologo
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed." }

# A developer's local settings hold their secrets. The guard PC gets its own
# through the setup page, so these must never ship.
foreach ($f in "appsettings.Site.json", "appsettings.Development.json", "appsettings.Site.example.json") {
    Remove-Item (Join-Path $Server $f) -ErrorAction SilentlyContinue
}

# --- Guard panel ---------------------------------------------------------------

Step "Building the guard panel"
Push-Location (Join-Path $Repo "aimpark_admin")
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }
    # same-origin: the panel talks to whichever server served it, so one build
    # works at localhost and at the PC's network address.
    flutter build web --release --dart-define=API_BASE_URL=same-origin
    if ($LASTEXITCODE -ne 0) { throw "flutter build web failed." }
}
finally { Pop-Location }
Copy-Item (Join-Path $Repo "aimpark_admin\build\web") (Join-Path $Server "admin-web") -Recurse

# --- Icon ------------------------------------------------------------------------

# An .ico holding the panel's PNG icon as is (Windows Vista and later read that).
$png = [IO.File]::ReadAllBytes((Join-Path $Repo "aimpark_admin\web\icons\Icon-192.png"))
$ico = New-Object IO.MemoryStream
$w = New-Object IO.BinaryWriter $ico
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]1)       # header: icon, 1 image
$w.Write([byte]192); $w.Write([byte]192); $w.Write([byte]0); $w.Write([byte]0)
$w.Write([UInt16]1); $w.Write([UInt16]32)                           # planes, bits per pixel
$w.Write([UInt32]$png.Length); $w.Write([UInt32]22)                 # size, offset
$w.Write($png); $w.Flush()
[IO.File]::WriteAllBytes((Join-Path $Build "aimpark.ico"), $ico.ToArray())

# --- Camera app (optional) -------------------------------------------------------

$defines = @("/DAppVersion=$Version", "/DPgInstaller=$PgFile")
$alpr = Join-Path $Repo "alpr-service\dist\AimParkALPR"
if (Test-Path (Join-Path $alpr "AimParkALPR.exe")) {
    Step "Including the ALPR camera app"
    Copy-Item $alpr (Join-Path $Build "alpr") -Recurse
    $defines += "/DWithAlpr"
}
else {
    Write-Warning "No alpr-service\dist\AimParkALPR\AimParkALPR.exe: building without the camera app."
}

# --- PostgreSQL ------------------------------------------------------------------

if (-not (Test-Path $PgFile)) {
    Step "Downloading PostgreSQL $PgVersion (~370 MB, once)"
    New-Item -ItemType Directory -Path (Split-Path $PgFile) -Force | Out-Null
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest $PgUrl -OutFile "$PgFile.part"
    Move-Item "$PgFile.part" $PgFile
}
$sig = Get-AuthenticodeSignature $PgFile
if ($sig.Status -ne "Valid" -or $sig.SignerCertificate.Subject -notlike "*EnterpriseDB*") {
    throw "The PostgreSQL installer's signature isn't valid. Delete $PgFile and run this again."
}

# --- Installer -------------------------------------------------------------------

Step "Building the installer"
& $iscc /Q @defines (Join-Path $Here "AimParkSetup.iss")
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed." }

$exe = Join-Path $Here "output\AimParkSetup-$Version.exe"
Write-Host "`nDone: $exe ($([math]::Round((Get-Item $exe).Length / 1MB)) MB)" -ForegroundColor Green
