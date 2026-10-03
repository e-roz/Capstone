; AimPark Site Server installer (Inno Setup 6).
;
; Don't compile this by hand: build-installer.ps1 publishes the server,
; builds the guard panel, then calls ISCC with the defines below.
;
; What the installer does on the guard PC:
;   1. Installs PostgreSQL 17 silently if the PC has none, with a random
;      password it saves to C:\ProgramData\AimPark\site-settings.json.
;   2. Copies the server (.NET built in, nothing else to install) and the
;      guard panel to C:\Program Files\AimPark.
;   3. Registers the "AimPark Site Server" Windows service: starts with the
;      PC, after PostgreSQL, and restarts itself after a crash.
;   4. Opens port 5041 on private networks only.
;   5. Adds an "AimPark Guard Panel" desktop shortcut, and opens it. The
;      first time, that's the setup page (site key + sign-in key).
;
; Running a newer AimParkSetup.exe over an old one updates in place: the
; program files are replaced; settings, gate reader links, photos and the
; database are kept.
;
; The server runs this itself for automatic updates (SiteUpdater.cs), with
; /VERYSILENT /SUPPRESSMSGBOXES and nobody watching: never add a plain MsgBox,
; use SuppressibleMsgBox so an unattended update can't hang on a dialog.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PgInstaller
  #error PgInstaller not defined. Run build-installer.ps1 instead of compiling this directly.
#endif

#define ServiceName "AimParkSite"
#define Port "5041"
#define FirewallRule "AimPark Site Server (5041)"
#define PanelUrl "http://localhost:5041/"

[Setup]
AppId={{6E0B3C1A-8C4F-4E57-9B7E-2A3F4D9C1E50}
AppName=AimPark Site Server
AppVersion={#AppVersion}
AppVerName=AimPark Site Server {#AppVersion}
AppPublisher=AimPark
DefaultDirName={autopf}\AimPark
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=output
OutputBaseFilename=AimParkSetup-{#AppVersion}
SetupIconFile=build\aimpark.ico
UninstallDisplayIcon={app}\aimpark.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
; The server is stopped by PrepareToInstall, not by Restart Manager.
CloseApplications=no

[Messages]
WelcomeLabel2=This sets up this PC as an AimPark guard post.%n%nIt installs the local database (if needed), the AimPark server and the guard panel. The server starts by itself whenever the PC turns on.%n%nKeep the site key from the online admin panel ready for the last step.

[Files]
Source: "build\server\*"; DestDir: "{app}\server"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "build\aimpark.ico"; DestDir: "{app}"; Flags: ignoreversion
#ifdef WithAlpr
Source: "build\alpr\*"; DestDir: "{app}\Camera"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif
Source: "{#PgInstaller}"; DestDir: "{tmp}"; DestName: "postgresql-setup.exe"; Flags: deleteafterinstall; Check: NeedsPostgres

[Dirs]
Name: "{commonappdata}\AimPark"

[Icons]
Name: "{commondesktop}\AimPark Guard Panel"; Filename: "{code:BrowserPath}"; Parameters: "{code:BrowserArgs}"; IconFilename: "{app}\aimpark.ico"; Comment: "Open the AimPark guard panel"
#ifdef WithAlpr
Name: "{commondesktop}\AimPark Camera"; Filename: "{app}\Camera\AimParkALPR.exe"; WorkingDir: "{app}\Camera"
; The camera app starts with Windows, for whoever signs in.
Name: "{commonstartup}\AimPark Camera"; Filename: "{app}\Camera\AimParkALPR.exe"; WorkingDir: "{app}\Camera"
#endif

[Run]
Filename: "{code:BrowserPath}"; Parameters: "{code:BrowserArgs}"; Description: "Open AimPark now"; Flags: postinstall nowait skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\net.exe"; Parameters: "stop {#ServiceName}"; Flags: runhidden; RunOnceId: "StopService"
Filename: "{sys}\sc.exe"; Parameters: "delete {#ServiceName}"; Flags: runhidden; RunOnceId: "DeleteService"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"""; Flags: runhidden; RunOnceId: "DeleteFirewallRule"

[Code]
var
  PostgresService: String;
  InstalledPostgres: Boolean;
  PostgresPassword: String;

{ ---- PostgreSQL ------------------------------------------------------- }

{ EDB's installer registers each server under this key. }
function FindPostgresService(): String;
var
  Names: TArrayOfString;
begin
  Result := '';
  if RegGetSubkeyNames(HKLM64, 'SOFTWARE\PostgreSQL\Services', Names) and (GetArrayLength(Names) > 0) then
    Result := Names[0];
end;

function NeedsPostgres(): Boolean;
begin
  Result := (PostgresService = '');
end;

function RandomPassword(Len: Integer): String;
var
  Chars: String;
  I: Integer;
begin
  Chars := 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  Result := '';
  for I := 1 to Len do
    Result := Result + Chars[Random(Length(Chars)) + 1];
end;

function InstallPostgres(): Boolean;
var
  Code: Integer;
begin
  PostgresPassword := RandomPassword(24);
  WizardForm.StatusLabel.Caption := 'Installing the local database (PostgreSQL). This takes a few minutes...';
  Result := Exec(ExpandConstant('{tmp}\postgresql-setup.exe'),
    '--mode unattended --unattendedmodeui none --superpassword "' + PostgresPassword + '"' +
    ' --serverport 5432 --disable-components stackbuilder',
    '', SW_HIDE, ewWaitUntilTerminated, Code) and (Code = 0);
  if Result then
  begin
    InstalledPostgres := True;
    PostgresService := FindPostgresService();
  end
  else
    Log(Format('PostgreSQL installer failed, exit code %d', [Code]));
end;

{ Only when this installer made PostgreSQL: it is the one that knows the
  password. With a PostgreSQL that was already there, the setup page asks. }
procedure SavePostgresSettings();
var
  Path: String;
  Code: Integer;
begin
  Path := ExpandConstant('{commonappdata}\AimPark\site-settings.json');
  if FileExists(Path) then
    exit;

  SaveStringToFile(Path,
    '{' + #13#10 +
    '  "ConnectionStrings": {' + #13#10 +
    '    "DefaultConnection": "Host=localhost;Port=5432;Database=AimParkSite;Username=postgres;Password=' + PostgresPassword + '"' + #13#10 +
    '  }' + #13#10 +
    '}' + #13#10, False);

  { Readable by SYSTEM (the service) and Administrators only. }
  Exec(ExpandConstant('{sys}\icacls.exe'),
    '"' + Path + '" /inheritance:r /grant:r *S-1-5-18:F *S-1-5-32-544:F',
    '', SW_HIDE, ewWaitUntilTerminated, Code);
end;

{ ---- Service ---------------------------------------------------------- }

function RunCmd(const Exe, Params: String): Integer;
begin
  if not Exec(Exe, Params, '', SW_HIDE, ewWaitUntilTerminated, Result) then
    Result := -1;
  Log(Format('%s %s -> %d', [Exe, Params, Result]));
end;

procedure InstallService();
var
  Sc, BinPath: String;
begin
  Sc := ExpandConstant('{sys}\sc.exe');
  BinPath := '"\"' + ExpandConstant('{app}\server\AimPark.API.exe') + '\" --environment Site --urls http://0.0.0.0:{#Port}"';

  WizardForm.StatusLabel.Caption := 'Registering the AimPark service...';
  if RunCmd(Sc, 'query {#ServiceName}') = 0 then
    RunCmd(Sc, 'config {#ServiceName} binPath= ' + BinPath + ' start= auto')
  else
    RunCmd(Sc, 'create {#ServiceName} binPath= ' + BinPath + ' start= auto DisplayName= "AimPark Site Server"');

  RunCmd(Sc, 'description {#ServiceName} "Makes gate decisions for AimPark at the guard post and syncs with the cloud."');
  { Restart 5 s after a crash, every time. failureflag 1 also counts a stop
    with an error code, which is how the setup page restarts the server. }
  RunCmd(Sc, 'failure {#ServiceName} reset= 86400 actions= restart/5000/restart/5000/restart/5000');
  RunCmd(Sc, 'failureflag {#ServiceName} 1');
  if PostgresService <> '' then
    RunCmd(Sc, 'config {#ServiceName} depend= ' + PostgresService);

  WizardForm.StatusLabel.Caption := 'Opening port {#Port} on private networks...';
  RunCmd(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall delete rule name="{#FirewallRule}"');
  RunCmd(ExpandConstant('{sys}\netsh.exe'),
    'advfirewall firewall add rule name="{#FirewallRule}" dir=in action=allow protocol=TCP localport={#Port} profile=private');

  WizardForm.StatusLabel.Caption := 'Starting AimPark...';
  RunCmd(ExpandConstant('{sys}\net.exe'), 'start {#ServiceName}');
end;

{ The first start may create the database tables, so give it a minute. }
function WaitForServer(): Boolean;
var
  Http: Variant;
  I: Integer;
begin
  Result := False;
  WizardForm.StatusLabel.Caption := 'Waiting for AimPark to answer...';
  for I := 1 to 60 do
  begin
    try
      Http := CreateOleObject('WinHttp.WinHttpRequest.5.1');
      Http.SetTimeouts(2000, 2000, 2000, 2000);
      Http.Open('GET', 'http://localhost:{#Port}/api/site/status', False);
      Http.Send('');
      if Http.Status = 200 then
      begin
        Result := True;
        exit;
      end;
    except
    end;
    Sleep(2000);
  end;
end;

{ ---- Shortcut target --------------------------------------------------- }

{ Edge in app mode: its own window, no address bar or tabs. Every Windows
  10/11 PC has it; the default browser is the fallback. }
function EdgePath(): String;
begin
  Result := ExpandConstant('{commonpf32}\Microsoft\Edge\Application\msedge.exe');
  if not FileExists(Result) then
    Result := ExpandConstant('{commonpf64}\Microsoft\Edge\Application\msedge.exe');
  if not FileExists(Result) then
    Result := '';
end;

function BrowserPath(Param: String): String;
begin
  Result := EdgePath();
  if Result = '' then
    Result := ExpandConstant('{win}\explorer.exe');
end;

function BrowserArgs(Param: String): String;
begin
  if EdgePath() <> '' then
    Result := '--app={#PanelUrl}'
  else
    Result := '{#PanelUrl}';
end;

{ ---- Install flow ------------------------------------------------------ }

function InitializeSetup(): Boolean;
begin
  PostgresService := FindPostgresService();
  InstalledPostgres := False;
  Result := True;
end;

{ An update: stop the running server so its files can be replaced. }
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Code: Integer;
begin
  Exec(ExpandConstant('{sys}\net.exe'), 'stop {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Result := '';
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssPostInstall then
    exit;

  if NeedsPostgres() then
  begin
    if not InstallPostgres() then
    begin
      SuppressibleMsgBox('The local database (PostgreSQL) could not be installed.' + #13#10 +
        'Install PostgreSQL 17 from postgresql.org, then run this setup again.' + #13#10#13#10 +
        'Details are in the setup log: ' + ExpandConstant('{log}'), mbError, MB_OK, IDOK);
      exit;
    end;
    SavePostgresSettings();
  end;

  InstallService();

  if not WaitForServer() then
    SuppressibleMsgBox('AimPark was installed, but it isn''t answering yet.' + #13#10 +
      'Wait a minute and open the AimPark Guard Panel shortcut. If it still' + #13#10 +
      'doesn''t open, check Event Viewer > Windows Logs > Application for "AimParkSite".',
      mbInformation, MB_OK, IDOK);
end;
