@echo off
cd /d "%~dp0"
where node >nul 2>nul
if %errorlevel%==0 (node server.js) else ("%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\6ef99b3d04073aa7\bin\node.exe" server.js)
pause
