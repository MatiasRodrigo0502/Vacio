; Instalador de Vacío para Windows (Inno Setup 6). Pedido por Matías el 2026-11-18:
; acceso directo en el escritorio, entrada en el menú Inicio, desinstalador (sale en
; «Aplicaciones instaladas» de Windows) y el icono del juego.
;
; LO HACE GITHUB en cada versión (trabajo «instalador» de publicar.yml), con el
; Vacio.exe recién exportado:
;
;     ISCC.exe /DVersion=0.N /DOrigen=<carpeta con Vacio.exe> instalador\vacio.iss
;
; y sale Vacio-instalador.exe en esa misma carpeta.
;
; POR QUÉ EN LA CARPETA DEL USUARIO Y NO EN «ARCHIVOS DE PROGRAMA»: el juego se
; actualiza solo cambiando su Vacio.exe (scripts/actualizacion.gd), y en Archivos de
; programa no puede escribir sin permiso de administrador. En
; %LOCALAPPDATA%\Programs\Vacio sí, y además el instalador no pide administrador.
;
; Al desinstalar NO se borra lo guardado (monedas, colección, ajustes, partidas):
; eso está en la carpeta de datos de Godot, no en la del juego. Sí lo que deja a
; medias el actualizador junto al .exe.

#ifndef Version
  #define Version "0.0"
#endif
#ifndef Origen
  #define Origen "..\build"
#endif

[Setup]
; Lo que identifica al juego en Windows: no cambiarlo nunca, o una versión nueva se
; instalaría como otro programa distinto.
AppId={{4CF06253-337A-4FC6-B8C4-A1F920869941}
AppName=Vacío
AppVersion={#Version}
AppVerName=Vacío {#Version}
AppPublisher=Equipo de Vacío
AppPublisherURL=https://github.com/MatiasRodrigo0502/Vacio
AppSupportURL=https://github.com/MatiasRodrigo0502/Vacio/releases/latest
DefaultDirName={localappdata}\Programs\Vacio
DefaultGroupName=Vacío
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#Origen}
OutputBaseFilename=Vacio-instalador
SetupIconFile=vacio.ico
UninstallDisplayIcon={app}\vacio.ico
UninstallDisplayName=Vacío
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Si el juego está abierto, lo cierra antes de cambiarlo.
CloseApplications=yes

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
; Marcado de entrada: el acceso directo en el escritorio era uno de los pedidos.
Name: "escritorio"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#Origen}\Vacio.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "vacio.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Vacío"; Filename: "{app}\Vacio.exe"; IconFilename: "{app}\vacio.ico"
Name: "{group}\Desinstalar Vacío"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Vacío"; Filename: "{app}\Vacio.exe"; IconFilename: "{app}\vacio.ico"; Tasks: escritorio

[Run]
Filename: "{app}\Vacio.exe"; Description: "{cm:LaunchProgram,Vacío}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Lo que deja el actualizador junto al juego: el .exe de antes y una descarga a medias.
Type: files; Name: "{app}\Vacio.viejo.*.exe"
Type: files; Name: "{app}\Vacio.exe.descarga"
