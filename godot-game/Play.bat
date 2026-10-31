@echo off
cd /d "%~dp0"
if exist "build\TankArena.exe" (
    start "" "build\TankArena.exe"
    exit /b
)
set "GODOT_PATH=%TEMP%\tank-godot-4.7.2-tools\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_PATH%" (
    start "" "%GODOT_PATH%" --path "%~dp0" --editor
    exit /b
)
echo Windows build not found. Open project.godot with Godot 4.7.2.
echo See README.md for instructions.
pause
