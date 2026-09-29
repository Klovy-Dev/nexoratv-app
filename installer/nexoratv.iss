; Installeur Windows de NexoraTV (Inno Setup 6).
; Ne pas lancer à la main : passer par installer\build.ps1, qui compile
; l'appli, fournit la version (/DAppVersion=…) et calcule l'empreinte
; SHA-256 à mettre dans update.json.
;
; Installation par utilisateur (pas de droits administrateur) : les mises à
; jour depuis l'appli s'installent sans fenêtre de contrôle de compte.

#define AppName "NexoraTV"
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppExe "nexoratv.exe"
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Identifiant FIXE : ne jamais le changer, sinon Windows verrait une autre
; application et les mises à jour ne remplaceraient plus l'installation.
AppId={{BF1A93ED-C120-435C-A2F9-AE8066C8C498}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=NexoraTV
AppPublisherURL=https://nexoratv.fr
AppSupportURL=https://nexoratv.fr
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\NexoraTV
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\build\installer
OutputBaseFilename=NexoraTV-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Ferme NexoraTV s'il tourne encore (fichiers verrouillés).
CloseApplications=force
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; Ressources de l'ancienne version (évite des fichiers orphelins).
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Installation normale : case « Lancer NexoraTV » à la fin.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; Mise à jour depuis l'appli (installation silencieuse) : relance directe.
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent
