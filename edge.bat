@echo off
REM Check for admin privileges
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    ECHO Requesting administrative privileges...
    powershell -Command "Start-Process -FilePath '%~dpnx0' -Verb RunAs"
    EXIT /B
)
PowerShell.exe -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
PowerShell.exe -Command "irm https://go.bibica.net/edge_disable_update | iex"
pause
