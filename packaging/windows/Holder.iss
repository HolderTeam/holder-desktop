#define AppName "Holder"
#define AppPublisher "HolderTeam"

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#ifndef StageDir
  #error StageDir must be passed to ISCC, for example /DStageDir=C:\path\to\Holder-windows-staged
#endif

[Setup]
AppId={{0D45D849-0E44-4B52-8F1E-DC59AE5B7A79}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={localappdata}\Programs\Holder
DefaultGroupName=Holder
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
OutputBaseFilename=Holder-{#AppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=packaging\windows\Holder.ico
UninstallDisplayIcon={app}\Holder.ico
ChangesEnvironment=yes
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
Name: "addtopath"; Description: "Add the Holder command-line tools (holderctl, holderd) to PATH"; GroupDescription: "Command-line integration:"

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "packaging\windows\Holder.ico"; DestDir: "{app}"; Flags: ignoreversion

[UninstallDelete]
Type: filesandordirs; Name: "{app}\cli"

[InstallDelete]
; Older installs shipped Holder.exe, a launcher that started the backend and then the app. The app starts
; its own backend now, so a Holder.exe left behind by an upgrade is removed.
Type: files; Name: "{app}\Holder.exe"

[Icons]
Name: "{group}\Holder"; Filename: "{app}\bin\holder-desktop.exe"; WorkingDir: "{app}"; IconFilename: "{app}\Holder.ico"
Name: "{group}\Holder Backend"; Filename: "{app}\bin\holderd.exe"; WorkingDir: "{app}\bin"; IconFilename: "{app}\Holder.ico"
Name: "{group}\Uninstall Holder"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Holder"; Filename: "{app}\bin\holder-desktop.exe"; WorkingDir: "{app}"; IconFilename: "{app}\Holder.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\bin\holder-desktop.exe"; WorkingDir: "{app}"; Description: "Launch Holder"; Flags: nowait postinstall skipifsilent unchecked

[Code]
const
  EnvironmentKey = 'Environment';
  PathValueName = 'Path';
  HwndBroadcast = $FFFF;
  WmSettingChange = $001A;
  SmtoAbortIfHung = $0002;

function SendMessageTimeout(
  Wnd: Longint;
  Msg: Longint;
  WParam: Longint;
  LParam: String;
  Flags: Longint;
  Timeout: Longint;
  var ResultValue: Longint
): Longint;
external 'SendMessageTimeoutW@user32.dll stdcall';

// The command-line tools go on PATH through small launchers in {app}\cli, not by putting {app}\bin
// on PATH: bin holds the GTK runtime and the daemon's DLLs, and every program that looks up a DLL by
// name would find Holder's copies. An earlier installer did put bin on PATH; that entry is removed.
function HolderCliDir(): string;
begin
  Result := ExpandConstant('{app}\cli');
end;

function HolderBinDir(): string;
begin
  Result := ExpandConstant('{app}\bin');
end;

function PathHasEntry(CurrentPath: string; Entry: string): Boolean;
begin
  Result := Pos(';' + Lowercase(Entry) + ';', ';' + Lowercase(CurrentPath) + ';') > 0;
end;

procedure NotifyEnvironmentChanged();
var
  ResultValue: Longint;
begin
  SendMessageTimeout(
    HwndBroadcast,
    WmSettingChange,
    0,
    'Environment',
    SmtoAbortIfHung,
    5000,
    ResultValue
  );
end;

// The path is written back as REG_EXPAND_SZ so entries such as %USERPROFILE%\bin keep expanding.
procedure AddPathEntry(Entry: string);
var
  CurrentPath: string;
  NewPath: string;
begin
  if not RegQueryStringValue(HKCU, EnvironmentKey, PathValueName, CurrentPath) then
    CurrentPath := '';

  if PathHasEntry(CurrentPath, Entry) then
    exit;

  if CurrentPath = '' then
    NewPath := Entry
  else
    NewPath := CurrentPath + ';' + Entry;

  RegWriteExpandStringValue(HKCU, EnvironmentKey, PathValueName, NewPath);
end;

procedure RemovePathEntry(Entry: string);
var
  CurrentPath: string;
begin
  if not RegQueryStringValue(HKCU, EnvironmentKey, PathValueName, CurrentPath) then
    exit;

  if Lowercase(CurrentPath) = Lowercase(Entry) then
    CurrentPath := '';

  StringChangeEx(CurrentPath, Entry + ';', '', True);
  StringChangeEx(CurrentPath, ';' + Entry, '', True);

  StringChangeEx(CurrentPath, ';;', ';', True);

  if CurrentPath = ';' then
    CurrentPath := '';
  if (Length(CurrentPath) > 0) and (Copy(CurrentPath, 1, 1) = ';') then
    Delete(CurrentPath, 1, 1);
  if (Length(CurrentPath) > 0) and (Copy(CurrentPath, Length(CurrentPath), 1) = ';') then
    Delete(CurrentPath, Length(CurrentPath), 1);

  RegWriteExpandStringValue(HKCU, EnvironmentKey, PathValueName, CurrentPath);
end;

procedure WriteLauncher(Name: string);
begin
  SaveStringToFile(
    HolderCliDir() + '\' + Name + '.cmd',
    '@echo off' + #13#10 + '"%~dp0..\bin\' + Name + '.exe" %*' + #13#10,
    False
  );
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ForceDirectories(HolderCliDir());
    WriteLauncher('holderctl');
    WriteLauncher('holderd');

    // An older installer put bin on PATH. Take that out whether or not the tools are added now.
    RemovePathEntry(HolderBinDir());
    if WizardIsTaskSelected('addtopath') then
      AddPathEntry(HolderCliDir());
    NotifyEnvironmentChanged();
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemovePathEntry(HolderCliDir());
    RemovePathEntry(HolderBinDir());
    NotifyEnvironmentChanged();
  end;
end;
