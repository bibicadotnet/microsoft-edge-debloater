<#
.SYNOPSIS
    Script to install Microsoft Edge with optimal clean configuration
.DESCRIPTION
    1. Install Edge in silent mode
    2. Disable all Edge background processes and auto-updates
    3. Download and apply registry tweaks to disable unwanted features
    4. Remove scheduled tasks created by Edge Update
.NOTES
    File Name      : install_edge.ps1
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
    # Download Edge installer silently
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2109047&Channel=Stable&language=en" -OutFile $EdgeInstaller -UseBasicParsing
    
    # Install Edge silently
    $installProcess = Start-Process -FilePath $EdgeInstaller -ArgumentList "/silent /install" -PassThru -Wait
    
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "Microsoft Edge installed successfully." -ForegroundColor Green
    } else {
        Write-Host "Edge installation completed with exit code $($installProcess.ExitCode)" -ForegroundColor Yellow
    }
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
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $RegFileUrl -OutFile $RegFile -UseBasicParsing
    Start-Process "regedit.exe" -ArgumentList "/s `"$RegFile`"" -Wait -NoNewWindow
    Write-Host "Registry tweaks applied successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error downloading or applying registry file: $_" -ForegroundColor Red
}

# 4. Remove Edge Update scheduled tasks
Write-Host "Removing Edge Update scheduled tasks..." -ForegroundColor Cyan

$TasksToRemove = @(
    "MicrosoftEdgeUpdateBrowserReplacementTask"
    "*MicrosoftEdgeUpdateTaskMachineCore*"
    "*MicrosoftEdgeUpdateTaskMachineUA*"
)

foreach ($pattern in $TasksToRemove) {
    try {
        $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -like $pattern }
        
        foreach ($task in $tasks) {
            try {
                # Disable task first if enabled
                if ($task.State -ne "Disabled") {
                    $task | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
                }
                
                # Delete the task
                $task | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                Write-Host "Removed task: $($task.TaskName)" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to remove task $($task.TaskName): $_" -ForegroundColor Yellow
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
