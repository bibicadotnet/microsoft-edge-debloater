<#
.SYNOPSIS
    Script to install Microsoft Edge with optimal clean configuration
.DESCRIPTION
    1. Install Edge in silent mode
    2. Disable all Edge background processes and auto-updates
    3. Download and apply registry tweaks to disable unwanted features
    4. Remove scheduled tasks created by Edge Update
    5. Completely disable MicrosoftEdgeUpdate.exe while preserving manual updates
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

# 2. Configure Edge Update policies
Write-Host "Configuring Edge Update policies..." -ForegroundColor Cyan

# Create registry keys if they don't exist
$EdgeUpdateRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
if (-not (Test-Path $EdgeUpdateRegPath)) {
    New-Item -Path $EdgeUpdateRegPath -Force | Out-Null
}

# Set registry values to disable auto-updates but allow manual updates
$updateSettings = @{
    "UpdateDefault" = 0
    "AutoUpdateCheckPeriodMinutes" = 0
    "DisableAutoUpdateChecksCheckboxValue" = 1
    "InstallDefault" = 0
    "AllowManualUpdateCheck" = 1  # This enables manual updates from Settings
}

foreach ($key in $updateSettings.Keys) {
    Set-ItemProperty -Path $EdgeUpdateRegPath -Name $key -Value $updateSettings[$key] -Type DWord
}

# 3. Completely stop and disable Edge Update processes
Write-Host "Stopping all Edge Update processes..." -ForegroundColor Cyan

# Stop any running Edge Update processes
try {
    Get-Process -Name "MicrosoftEdgeUpdate" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Stopped all MicrosoftEdgeUpdate.exe processes" -ForegroundColor Green
}
catch {
    Write-Host "Error stopping MicrosoftEdgeUpdate processes: $_" -ForegroundColor Red
}

# 4. Disable Edge Update services
Write-Host "Disabling Edge Update services..." -ForegroundColor Cyan

$services = @("edgeupdate", "edgeupdatem")
foreach ($service in $services) {
    try {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            # Stop the service if it's running
            if ($svc.Status -eq "Running") {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
            }
            # Disable the service
            Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "Disabled service: $service" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error configuring service $($service): $_" -ForegroundColor Red
    }
}

# 5. Remove scheduled update tasks
Write-Host "Removing Edge Update scheduled tasks..." -ForegroundColor Cyan

$TasksToRemove = @(
    "MicrosoftEdgeUpdateBrowserReplacementTask",
    "MicrosoftEdgeUpdateTaskMachineCore",
    "MicrosoftEdgeUpdateTaskMachineUA"
)

foreach ($taskName in $TasksToRemove) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            # Disable task first if enabled
            if ($task.State -ne "Disabled") {
                $task | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            }
            # Delete the task
            $task | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
            Write-Host "Removed task: $taskName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Failed to remove task ${taskName}: $_" -ForegroundColor Yellow
    }
}

# 6. Apply additional registry tweaks
Write-Host "Applying additional registry tweaks..." -ForegroundColor Cyan
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

# Cleanup temporary files
Remove-Item -Path $EdgeInstaller -ErrorAction SilentlyContinue
Remove-Item -Path $RegFile -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge clean installation completed!" -ForegroundColor Green
Write-Host "Manual updates from Settings will work, but automatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow
