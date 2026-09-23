@echo off
rem Launcher for dev.ps1 : works even if PowerShell scripts are blocked by the execution policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1"
