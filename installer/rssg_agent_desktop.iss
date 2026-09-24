; Installer RSSG Agent Desktop (Inno Setup 6).
; Build: iscc /DAppVersion=1.2.0 installer\rssg_agent_desktop.iss
; Menjalankan setup di atas versi lama akan menutup aplikasi yang masih
; berjalan (termasuk yang tersembunyi di tray), menimpa file, lalu
; menjalankannya kembali. Pengaturan (SharedPreferences) tidak tersentuh.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "RSSG Agent Desktop"
#define AppExe "rssg_agent_desktop.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{6F2B8C4E-3A1D-4E7B-9C55-2D8E41A7B913}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=RSUD dr. Soeratno Gemolong
; Per-user install tanpa UAC. Folder tujuan = folder agent yang sedang
; berjalan (copy manual lama ikut tertimpa), lalu folder install sebelumnya.
PrivilegesRequired=lowest
DefaultDirName={code:GetDefaultDir}
UsePreviousAppDir=no
DisableDirPage=auto
DisableProgramGroupPage=yes
DisableReadyPage=yes
UsePreviousTasks=yes
; Proses lama dimatikan sendiri di PrepareToInstall.
CloseApplications=no
RestartApplications=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=RSSG-Agent-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "autostart"; Description: "Jalankan otomatis saat Windows menyala"
Name: "desktopicon"; Description: "Buat shortcut di Desktop"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Buang sisa file versi lama agar tidak tercampur dengan versi baru.
Type: filesandordirs; Name: "{app}\data"

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "RSSGAgentDesktop"; ValueData: """{app}\{#AppExe}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#AppExe}"; Description: "Jalankan {#AppName}"; WorkingDir: "{app}"; Flags: nowait postinstall

[Code]
const
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{6F2B8C4E-3A1D-4E7B-9C55-2D8E41A7B913}_is1';

var
  DetectedDir: String;

// Folder exe agent yang sedang berjalan, kosong jika tidak ada.
function FindRunningAgentDir: String;
var
  OutFile: String;
  ExePath: AnsiString;
  ResultCode: Integer;
begin
  Result := '';
  OutFile := ExpandConstant('{tmp}\agent_path.txt');
  Exec('powershell.exe',
    '-NoProfile -NonInteractive -Command "(Get-Process -Name rssg_agent_desktop ' +
    '-ErrorAction SilentlyContinue | Select-Object -First 1).Path | ' +
    'Out-File -Encoding ascii -FilePath ''' + OutFile + '''"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  if LoadStringFromFile(OutFile, ExePath) then
  begin
    ExePath := Trim(ExePath);
    if (ExePath <> '') and FileExists(ExePath) then
      Result := ExtractFileDir(ExePath);
  end;
end;

function InitializeSetup(): Boolean;
begin
  DetectedDir := FindRunningAgentDir;
  Result := True;
end;

function GetDefaultDir(Param: String): String;
var
  PreviousDir: String;
begin
  if DetectedDir <> '' then
    Result := DetectedDir
  else if RegQueryStringValue(HKCU, UninstallKey, 'Inno Setup: App Path', PreviousDir)
    and (PreviousDir <> '') then
    Result := PreviousDir
  else
    Result := ExpandConstant('{localappdata}\Programs\{#AppName}');
end;

// Folder agent lama sudah terdeteksi: langsung timpa tanpa bertanya.
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = wpSelectDir) and (DetectedDir <> '');
end;

procedure KillRunningAgent;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /T /IM {#AppExe}', '',
    SW_HIDE, ewWaitUntilTerminated, ResultCode);
  // Beri waktu Windows melepas lock file .exe/.dll.
  Sleep(1500);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillRunningAgent;
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  KillRunningAgent;
  Result := True;
end;
