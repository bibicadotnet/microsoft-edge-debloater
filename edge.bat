@echo off
powershell -Command "Invoke-WebRequest 'https://go.bibica.net/edge' -OutFile 'edge.ps1'; powershell -ExecutionPolicy Bypass -File 'edge.ps1'"
pause
