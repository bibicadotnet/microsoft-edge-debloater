<#
.SYNOPSIS
    Script to install Microsoft Edge with optimal clean configuration
.DESCRIPTION
    1. Install Edge in silent mode
    2. Disable all Edge background processes and auto-updates
    3. Download and apply registry tweaks to disable unwanted features
    4. Remove scheduled tasks created by Edge Update
    5. Completely disable MicrosoftEdgeUpdate.exe while preserving manual updates
    6. Rename Edge Update executables and create lock files to prevent re-creation or modification.
    7. Apply additional registry tweaks to optimize Edge configuration.
.NOTES
    File Name      : install_edge.ps1
    Prerequisite   : PowerShell 5.1 or later, Administrator rights
#>

# Require Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator rights. Please run PowerShell as Administrator." -ForegroundColor Red
    exit
}

# Function to perform operation with retry logic
function Invoke-WithRetry {
    param (
        [ScriptBlock]$ScriptBlock,
        [string]$OperationName,
        [int]$MaxRetries = 3,
        [int]$RetryDelay = 5
    )
    
    $attempt = 1
    $lastError = $null
    
    while ($attempt -le $MaxRetries) {
        try {
            Write-Host "[Attempt $attempt/$MaxRetries] $OperationName" -ForegroundColor Cyan
            $result = & $ScriptBlock
            return $result
        }
        catch {
            $lastError = $_
            Write-Host "Attempt $attempt failed: $_" -ForegroundColor Yellow
            $attempt++
            
            if ($attempt -le $MaxRetries) {
                Write-Host "Retrying in $RetryDelay seconds..." -ForegroundColor Yellow
                Start-Sleep -Seconds $RetryDelay
            }
        }
    }
    
    Write-Host "Operation failed after $MaxRetries attempts." -ForegroundColor Red
    Write-Host "Last error details: $lastError" -ForegroundColor Red
    throw $lastError
}

# Function to stop processes gracefully
function Stop-EdgeProcesses {
    Write-Host "Checking for running Edge processes..." -ForegroundColor Cyan
    
    $edgeProcesses = @("msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem")
    $browserRunning = $false
    
    foreach ($process in $edgeProcesses) {
        try {
            $runningProcs = Get-Process -Name $process -ErrorAction SilentlyContinue
            if ($runningProcs) {
                Write-Host "Found running $process processes. Attempting to close..." -ForegroundColor Yellow
                $browserRunning = $true
                
                # Try graceful close first
                $runningProcs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
                Start-Sleep -Seconds 3
                
                # Force terminate if still running
                if (!$runningProcs.HasExited) {
                    $runningProcs | Stop-Process -Force -ErrorAction SilentlyContinue
                    Write-Host "Force terminated $process processes" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Host "Error stopping $process processes: $_" -ForegroundColor Red
        }
    }
    
    if ($browserRunning) {
        Write-Host "All Edge related processes have been terminated." -ForegroundColor Green
        # Recommend user to save work if browser was running
        Write-Host "Note: Any unsaved work in Edge may have been lost." -ForegroundColor Yellow
    }
    else {
        Write-Host "No Edge processes were running." -ForegroundColor Green
    }
}

# 0. Stop all Edge processes before installation
Stop-EdgeProcesses

# Define the Edge installer path early
$EdgeInstaller = "$env:TEMP\MicrosoftEdgeSetup.exe"

# Ensure the installer file is not in use or delete it if it exists from a previous failed attempt.
if (Test-Path $EdgeInstaller) {
    try {
        Remove-Item -Path $EdgeInstaller -Force -ErrorAction Stop
        Write-Host "Removed old installer file: $EdgeInstaller" -ForegroundColor Green
    }
    catch {
        Write-Host "[WARNING] Could not remove old installer file: $EdgeInstaller. It might be in use. Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 1. Download and install Edge silently with retry
Write-Host "Starting Microsoft Edge download and installation..." -ForegroundColor Cyan

try {
    # Download Edge installer with retry
    Invoke-WithRetry -OperationName "Downloading Edge installer" -ScriptBlock {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?linkid=2109047&Channel=Stable&language=en" -OutFile $EdgeInstaller -UseBasicParsing
    }
    
    # Install Edge with retry
    $installProcess = Invoke-WithRetry -OperationName "Installing Microsoft Edge" -ScriptBlock {
        $process = Start-Process -FilePath $EdgeInstaller -ArgumentList "/silent /install" -PassThru -Wait
        return $process
    }
    
    if ($installProcess.ExitCode -eq 0) {
        Write-Host "Microsoft Edge installed successfully." -ForegroundColor Green
    } else {
        Write-Host "Edge installation completed with exit code $($installProcess.ExitCode)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Fatal error during Edge installation: $_" -ForegroundColor Red
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

# 5. Remove scheduled update tasks with retry
Write-Host "Removing Edge Update scheduled tasks..." -ForegroundColor Cyan

$TasksToRemove = @(
    "MicrosoftEdgeUpdateBrowserReplacementTask*",
    "MicrosoftEdgeUpdateTaskMachineCore*",
    "MicrosoftEdgeUpdateTaskMachineUA*"
)

foreach ($taskName in $TasksToRemove) {
    try {
        Invoke-WithRetry -OperationName "Removing task $taskName" -ScriptBlock {
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
    }
    catch {
        Write-Host "Failed to remove task ${taskName} after retries: $_" -ForegroundColor Red
    }
}

# 6. Disable Edge Update executables by renaming and locking
Write-Host "Disabling Edge Update executables..." -ForegroundColor Cyan

$EdgeUpdateExeFiles = @(
    "${env:ProgramFiles}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
)

foreach ($file in (Get-Item $EdgeUpdateExeFiles -ErrorAction SilentlyContinue)) {
    try {
        # 1. Stop any running instances
        $processName = $file.BaseName
        Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Host "Stopped process: $($file.Name)" -ForegroundColor Green

        # 2. Disable by renaming executable
        $disabledPath = $file.FullName + ".disabled"
        Rename-Item -Path $file.FullName -NewName $disabledPath -Force
        Write-Host "Renamed executable: $($file.Name) to $($file.Name).disabled" -ForegroundColor Green

        # 3. Create lock file (ReadOnly + Hidden + System)
        New-Item -Path $file.FullName -ItemType File -Force | Out-Null
        (Get-Item $file.FullName).Attributes = "ReadOnly, Hidden, System"
        Write-Host "Created lock file: $($file.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to disable $($file.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 7. Apply additional registry tweaks with retry
Write-Host "Applying additional registry tweaks..." -ForegroundColor Cyan

# First, apply restore-default.reg to reset any existing settings
$RestoreRegFileUrl = "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/restore-default.reg"
$RestoreRegFile = "$env:TEMP\restore_default.reg"

try {
    Write-Host "Downloading and applying restore-default.reg..." -ForegroundColor Cyan
    Invoke-WithRetry -OperationName "Downloading restore-default registry file" -ScriptBlock {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $RestoreRegFileUrl -OutFile $RestoreRegFile -UseBasicParsing
    }
    
    Invoke-WithRetry -OperationName "Applying restore-default registry tweaks" -ScriptBlock {
        Start-Process "regedit.exe" -ArgumentList "/s `"$RestoreRegFile`"" -Wait -NoNewWindow
    }
    
    Write-Host "Restore-default registry tweaks applied successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error applying restore-default registry tweaks: $_" -ForegroundColor Red
}

# Then apply the custom vi.edge.reg settings
$RegFileUrl = "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/vi.edge.reg"
$RegFile = "$env:TEMP\edge_settings.reg"

try {
    Invoke-WithRetry -OperationName "Downloading registry tweaks" -ScriptBlock {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $RegFileUrl -OutFile $RegFile -UseBasicParsing
    }
    
    Invoke-WithRetry -OperationName "Applying registry tweaks" -ScriptBlock {
        Start-Process "regedit.exe" -ArgumentList "/s `"$RegFile`"" -Wait -NoNewWindow
    }
    
    Write-Host "Custom registry tweaks applied successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error applying custom registry tweaks after retries: $_" -ForegroundColor Red
}

# Cleanup temporary files
Remove-Item -Path $EdgeInstaller -ErrorAction SilentlyContinue
Remove-Item -Path $RegFile -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge clean installation completed!" -ForegroundColor Green
Write-Host "Manual updates from Settings will work, but automatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow
