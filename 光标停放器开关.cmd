@echo off
start "" /b powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launcher.ps1" -ToggleRunning
exit /b
