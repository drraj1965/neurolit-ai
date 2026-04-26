#define MyAppName "NeuroLit AI"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "NeuroLit AI"
#define MyAppExeName "neurolit_review_app.exe"
#define MyReleaseDir "..\build\windows\x64\runner\Release"
#define MyBackendDir "..\backend\dist\neurolit_backend"
#define MyLauncherScript "..\launch_neurolit_app.vbs"

[Setup]
AppId={{8C43734E-2C31-4B66-8D79-9F0B9E1A8A4C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={pf}\NeuroLit AI
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma
SolidCompression=yes
WizardStyle=modern
OutputDir=output
OutputBaseFilename=NeuroLit_Setup
UninstallDisplayIcon={app}\{#MyAppExeName}
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyBackendDir}\*"; DestDir: "{app}\backend_runtime"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyLauncherScript}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch_neurolit_app.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch_neurolit_app.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\launch_neurolit_app.vbs"""; Description: "Launch {#MyAppName}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
