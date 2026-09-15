@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0manage_startup.ps1" -Action Toggle
pause
