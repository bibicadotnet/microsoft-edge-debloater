# Script to completely remove Microsoft Edge from Windows
# Requires Administrator privileges

# Check for Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as Administrator!" -ForegroundColor Red
    pause
    exit
}

Write-Host "Starting Microsoft Edge removal process..." -ForegroundColor Yellow

# Stop all Edge processes
Write-Host "Stopping Edge processes..."
Get-Process -Name msedge, MicrosoftEdge, MicrosoftEdgeUpdate -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Remove Edge using DISM (for Windows 10/11)
Write-Host "Attempting to remove Edge with DISM..."
try {
    $edgePackage = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.MicrosoftEdge"}
    if ($edgePackage) {
        Remove-AppxProvisionedPackage -Online -PackageName $edgePackage.PackageName -ErrorAction Stop
        Write-Host "Successfully removed Edge provisioned package" -ForegroundColor Green
    } else {
        Write-Host "No Edge provisioned package found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "DISM removal failed (may not be applicable for this Windows version): $_" -ForegroundColor Yellow
}

# Remove Edge packages for all users
Write-Host "Removing Edge packages..."
Get-AppxPackage -AllUsers -Name Microsoft.MicrosoftEdge | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxPackage -AllUsers -Name Microsoft.Edge | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

# Remove Edge Chromium versions
Write-Host "Removing Edge Chromium installations..."
$edgePaths = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Beta",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Dev",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Canary"
)

foreach ($path in $edgePaths) {
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "Removed: $path" -ForegroundColor Green
        } catch {
            Write-Host "Failed to remove $path : $_" -ForegroundColor Red
        }
    }
}

# Remove shortcuts
Write-Host "Removing shortcuts..."
$publicDesktop = [Environment]::GetFolderPath("CommonDesktopDirectory")
$startMenu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
$edgeShortcuts = @(
    "$publicDesktop\Microsoft Edge.lnk",
    "$startMenu\Microsoft Edge.lnk"
)

foreach ($shortcut in $edgeShortcuts) {
    if (Test-Path $shortcut) {
        try {
            Remove-Item $shortcut -Force -ErrorAction Stop
        } catch {
            Write-Host "Failed to remove shortcut $shortcut : $_" -ForegroundColor Yellow
        }
    }
}

# Clean registry entries
Write-Host "Cleaning registry entries..."
$edgeRegKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate",
    "HKCU:\Software\Microsoft\Edge",
    "HKCU:\Software\Microsoft\EdgeUpdate"
)

foreach ($regKey in $edgeRegKeys) {
    if (Test-Path $regKey) {
        try {
            Remove-Item -Path $regKey -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Failed to remove registry key $regKey : $_" -ForegroundColor Yellow
        }
    }
}

# Remove user data
Write-Host "Removing user data..."
$edgeDataPaths = @(
    "$env:LOCALAPPDATA\Microsoft\Edge",
    "$env:LOCALAPPDATA\Microsoft\EdgeUpdate",
    "$env:APPDATA\Microsoft\Edge",
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk"
)

foreach ($dataPath in $edgeDataPaths) {
    if (Test-Path $dataPath) {
        try {
            Remove-Item -Path $dataPath -Recurse -Force -ErrorAction Stop
        } catch {
            Write-Host "Failed to remove user data at $dataPath : $_" -ForegroundColor Yellow
        }
    }
}

Write-Host "Microsoft Edge has been completely removed!" -ForegroundColor Green
Write-Host "Note: Windows Update may reinstall Edge in future updates." -ForegroundColor Yellow
pause
