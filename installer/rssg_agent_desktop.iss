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
; Per-user install: tanpa UAC, dan update selalu ke folder yang sama.
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DisableDirPage=yes
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
