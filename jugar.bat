@echo off
REM Lanza el juego con un doble clic, sin abrir el editor de Godot.
REM Busca el ejecutable en varios sitios: si lo mueves o si otra persona del
REM equipo lo tiene en otra ruta, solo hay que anadir una linea SET mas abajo.

setlocal
set "PROYECTO=%~dp0"

REM 1) Si Godot esta en el PATH, se usa ese.
where godot >nul 2>nul && (
	start "" godot --path "%PROYECTO%."
	exit /b
)

REM 2) Rutas conocidas. La primera que exista, gana.
set "GODOT=%USERPROFILE%\OneDrive - vidalibarraquer.net\Escritorio\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :lanzar

set "GODOT=C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :lanzar

set "GODOT=%USERPROFILE%\Desktop\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :lanzar

echo No encuentro Godot.
echo Abre jugar.bat con el bloc de notas y anade la ruta de tu Godot_*.exe.
pause
exit /b 1

:lanzar
start "" "%GODOT%" --path "%PROYECTO%."
