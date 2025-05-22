<#
.SYNOPSIS
    Script to install Microsoft Edge with optimal clean configuration
.DESCRIPTION
    1. Install Edge in silent mode
    2. Disable all Edge background processes and auto-updates
    3. Download and apply registry tweaks to disable unwanted features
    4. Remove scheduled tasks created by Edge Update
.NOTES
    File Name      : Install-EdgeClean.ps1
    Prerequisite   : PowerShell 5.1 or later, Administrator rights
#>

# Require Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator rights. Please run PowerShell as Administrator." -ForegroundColor Red
    exit
}

# 1. Download and install Edge silently
Write-Host "Downloading and installing Microsoft Edge..." -ForegroundColor Cyan
$EdgeInstaller = "$env:TEMP\MicrosoftEdgeSetup.exe"

try {
    # Download Edge installer
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2109047&Channel=Stable&language=en" -OutFile $EdgeInstaller -UseBasicParsing
    
    # Install Edge silently
    Start-Process -FilePath $EdgeInstaller -ArgumentList "/silent /install" -Wait
    
    Write-Host "Microsoft Edge installed successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error downloading or installing Edge: $_" -ForegroundColor Red
    exit
}

# 2. Disable Edge background processes and auto-updates
Write-Host "Disabling Edge background processes and auto-updates..." -ForegroundColor Cyan

# Disable auto-updates via registry
$EdgeUpdateRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
if (-not (Test-Path $EdgeUpdateRegPath)) {
    New-Item -Path $EdgeUpdateRegPath -Force | Out-Null
}
Set-ItemProperty -Path $EdgeUpdateRegPath -Name "UpdateDefault" -Value 0 -Type DWord
Set-ItemProperty -Path $EdgeUpdateRegPath -Name "AutoUpdateCheckPeriodMinutes" -Value 0 -Type DWord

# Disable background mode
$EdgeBackgroundRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $EdgeBackgroundRegPath)) {
    New-Item -Path $EdgeBackgroundRegPath -Force | Out-Null
}
Set-ItemProperty -Path $EdgeBackgroundRegPath -Name "BackgroundModeEnabled" -Value 0 -Type DWord

# 3. Download and apply registry tweaks
Write-Host "Downloading and applying registry tweaks..." -ForegroundColor Cyan
$RegFileUrl = "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/vi.edge.reg"
$RegFile = "$env:TEMP\edge_settings.reg"

try {
    Invoke-WebRequest -Uri $RegFileUrl -OutFile $RegFile -UseBasicParsing
    Start-Process "regedit.exe" -ArgumentList "/s `"$RegFile`"" -Wait
    Write-Host "Registry tweaks applied successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error downloading or applying registry file: $_" -ForegroundColor Red
}

# 4. Remove Edge Update scheduled tasks
Write-Host "Removing Edge Update scheduled tasks..." -ForegroundColor Cyan

# Get all tasks that match our patterns
$TasksToRemove = @(
    "MicrosoftEdgeUpdateBrowserReplacementTask"
    "*MicrosoftEdgeUpdateTaskMachineCore*"
    "*MicrosoftEdgeUpdateTaskMachineUA*"
)

foreach ($pattern in $TasksToRemove) {
    try {
        $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like $pattern }
        
        foreach ($task in $tasks) {
            Write-Host "Processing task: $($task.TaskName)" -ForegroundColor Cyan
            
            # First disable the task if it's enabled
            if ($task.State -ne "Disabled") {
                try {
                    Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop | Out-Null
                    Write-Host " - Disabled task" -ForegroundColor DarkGray
                }
                catch {
                    Write-Host " - Could not disable task: $_" -ForegroundColor Yellow
                }
            }
            
            # Then delete the task
            try {
                Unregister-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop | Out-Null
                Write-Host " - Successfully removed task" -ForegroundColor Green
            }
            catch {
                Write-Host " - Could not remove task: $_" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Error processing task pattern '$pattern': $_" -ForegroundColor Yellow
    }
}

# Cleanup temporary files
Remove-Item -Path $EdgeInstaller -ErrorAction SilentlyContinue
Remove-Item -Path $RegFile -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge clean installation completed!" -ForegroundColor Green
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow