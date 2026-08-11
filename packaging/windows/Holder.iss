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
UninstallDisplayIcon={app}\bin\holder-desktop.exe
ChangesEnvironment=yes
SetupLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
Name: "addtopath"; Description: "Add Holder command-line tools to PATH"; GroupDescription: "Command-line integration:"; Flags: checkedonce

[Files]
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Holder"; Filename: "{app}\bin\holder-desktop.exe"; WorkingDir: "{app}\bin"
Name: "{group}\Holder Backend"; Filename: "{app}\bin\holderd.exe"; WorkingDir: "{app}\bin"
Name: "{group}\Uninstall Holder"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Holder"; Filename: "{app}\bin\holder-desktop.exe"; WorkingDir: "{app}\bin"; Tasks: desktopicon

[Run]
Filename: "{app}\bin\holder-desktop.exe"; Description: "Launch Holder"; Flags: nowait postinstall skipifsilent unchecked

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

procedure AddHolderToUserPath();
var
  CurrentPath: string;
  NewPath: string;
  Entry: string;
begin
  Entry := HolderBinDir();
  if not RegQueryStringValue(HKCU, EnvironmentKey, PathValueName, CurrentPath) then
    CurrentPath := '';

  if PathHasEntry(CurrentPath, Entry) then
    exit;

  if CurrentPath = '' then
    NewPath := Entry
  else
    NewPath := CurrentPath + ';' + Entry;

  RegWriteStringValue(HKCU, EnvironmentKey, PathValueName, NewPath);
  NotifyEnvironmentChanged();
end;

procedure RemoveHolderFromUserPath();
var
  CurrentPath: string;
  NewPath: string;
  Entry: string;
  Parts: TArrayOfString;
  I: Integer;
begin
  Entry := HolderBinDir();
  if not RegQueryStringValue(HKCU, EnvironmentKey, PathValueName, CurrentPath) then
    exit;

  StringChangeEx(CurrentPath, Entry + ';', '', True);
  StringChangeEx(CurrentPath, ';' + Entry, '', True);

  if Lowercase(CurrentPath) = Lowercase(Entry) then
    CurrentPath := '';

  NewPath := '';
  StringChangeEx(CurrentPath, ';;', ';', True);
  StringChangeEx(CurrentPath, ';', #13#10, True);
  Parts := SplitString(CurrentPath, #13#10);
  for I := 0 to GetArrayLength(Parts) - 1 do begin
    if (Parts[I] <> '') and (Lowercase(Parts[I]) <> Lowercase(Entry)) then begin
      if NewPath = '' then
        NewPath := Parts[I]
      else
        NewPath := NewPath + ';' + Parts[I];
    end;
  end;

  RegWriteStringValue(HKCU, EnvironmentKey, PathValueName, NewPath);
  NotifyEnvironmentChanged();
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and IsTaskSelected('addtopath') then
    AddHolderToUserPath();
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    RemoveHolderFromUserPath();
end;
