@echo off
set "SCRIPT=%~dp0isoDebloaterScript.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
