; Instalador de Vacío para Windows (Inno Setup 6). Pedido por Matías el 2026-11-18:
; acceso directo en el escritorio, entrada en el menú Inicio, desinstalador (sale en
; «Aplicaciones instaladas» de Windows) y el icono del juego.
;
; DESDE EL 2026-11-19 INSTALA EL LANZADOR (VacioLanzador.exe, el proyecto lanzador/),
; no el juego. Matías: «que instale algo parecido a lo que tiene el Minecraft, que
; puedes instalar la versión que quieras y jugarla». El lanzador baja cada versión a
; %LOCALAPPDATA%\Vacio\versiones\0.N\ y la abre desde ahí.
;
; LO HACE GITHUB en cada versión (trabajo «instalador» de publicar.yml), con el
; VacioLanzador.exe recién exportado:
;
;     ISCC.exe /DVersion=0.N /DOrigen=<carpeta con Vacio.exe> instalador\vacio.iss
;
; y sale Vacio-instalador.exe en esa misma carpeta.
;
; EN LA CARPETA DEL USUARIO Y NO EN «ARCHIVOS DE PROGRAMA»: así no pide permiso de
; administrador, ni para instalarlo ni para que el lanzador baje versiones.
;
; Al desinstalar NO se borra lo guardado (monedas, colección, ajustes, partidas):
; eso está en la carpeta de datos de Godot, no en la del juego. Sí las versiones que
; bajó el lanzador, y lo que dejaba el actualizador de antes junto al .exe.

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
Source: "{#Origen}\VacioLanzador.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "vacio.ico"; DestDir: "{app}"; Flags: ignoreversion

[InstallDelete]
; El juego suelto que instalaba este instalador antes del lanzador: ya no se usa.
Type: files; Name: "{app}\Vacio.exe"
Type: files; Name: "{app}\Vacio.viejo.*.exe"

[Icons]
Name: "{group}\Vacío"; Filename: "{app}\VacioLanzador.exe"; IconFilename: "{app}\vacio.ico"
Name: "{group}\Desinstalar Vacío"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Vacío"; Filename: "{app}\VacioLanzador.exe"; IconFilename: "{app}\vacio.ico"; Tasks: escritorio

[Run]
Filename: "{app}\VacioLanzador.exe"; Description: "{cm:LaunchProgram,Vacío}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Las versiones que bajó el lanzador (lanzador/lanzador.gd, carpeta_versiones).
Type: filesandordirs; Name: "{localappdata}\Vacio\versiones"
Type: dirifempty; Name: "{localappdata}\Vacio"
