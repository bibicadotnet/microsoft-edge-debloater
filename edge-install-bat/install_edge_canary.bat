@echo off
REM Install Microsoft Edge Canary
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    EXIT /B
)
PowerShell.exe -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
set EDGE_CHANNEL=canary
PowerShell.exe -Command "irm https://go.bibica.net/edge | iex"
pause