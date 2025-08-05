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
    "${env:ProgramFiles(x86)}\Microsoft\EdgeCore",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeWebView",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Beta",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Dev",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Canary",
    "${env:ProgramFiles}\Microsoft\Edge",
    "${env:ProgramFiles}\Microsoft\Edge Beta",
    "${env:ProgramFiles}\Microsoft\Edge Dev",
    "${env:ProgramFiles}\Microsoft\Edge Canary"
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

# Remove shortcuts - COMPREHENSIVE VERSION
Write-Host "Removing shortcuts from all locations..."

# Get all possible shortcut locations
$shortcutLocations = @(
    [Environment]::GetFolderPath("Desktop"),                    # Current user desktop
    [Environment]::GetFolderPath("CommonDesktopDirectory"),     # Public/All users desktop
    [Environment]::GetFolderPath("Programs"),                   # Current user Start Menu
    [Environment]::GetFolderPath("CommonPrograms"),             # All users Start Menu
    [Environment]::GetFolderPath("StartMenu"),                  # Current user Start Menu root
    [Environment]::GetFolderPath("CommonStartMenu"),            # All users Start Menu root
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",      # Current user programs
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",  # All users programs
    "$env:PUBLIC\Desktop",                                      # Public desktop (alternative path)
    "$env:USERPROFILE\Desktop",                                 # Current user desktop (alternative path)
    "$env:ALLUSERSPROFILE\Desktop"                              # All users desktop (if exists)
)

# Possible Edge shortcut names
$edgeShortcutNames = @(
    "Microsoft Edge.lnk",
    "Microsoft Edge Beta.lnk",
    "Microsoft Edge Dev.lnk", 
    "Microsoft Edge Canary.lnk",
    "Edge.lnk",
    "Microsoft Edge.url"
)

# Remove shortcuts from all locations
foreach ($location in $shortcutLocations) {
    if (Test-Path $location) {
        Write-Host "Checking location: $location" -ForegroundColor Cyan
        
        foreach ($shortcutName in $edgeShortcutNames) {
            $shortcutPath = Join-Path $location $shortcutName
            
            if (Test-Path $shortcutPath) {
                try {
                    Remove-Item $shortcutPath -Force -ErrorAction Stop
                    Write-Host "  Removed: $shortcutPath" -ForegroundColor Green
                } catch {
                    Write-Host "  Failed to remove: $shortcutPath - $_" -ForegroundColor Red
                }
            }
        }
        
        # Also search for any shortcut that might link to Edge
        try {
            $edgeShortcuts = Get-ChildItem -Path $location -Filter "*.lnk" -ErrorAction SilentlyContinue | 
                Where-Object { 
                    $shell = New-Object -ComObject WScript.Shell
                    $shortcut = $shell.CreateShortcut($_.FullName)
                    $target = $shortcut.TargetPath
                    $target -match "msedge|edge\.exe|MicrosoftEdge"
                }
            
            foreach ($shortcut in $edgeShortcuts) {
                try {
                    Remove-Item $shortcut.FullName -Force -ErrorAction Stop
                    Write-Host "  Removed Edge-related shortcut: $($shortcut.Name)" -ForegroundColor Green
                } catch {
                    Write-Host "  Failed to remove: $($shortcut.FullName) - $_" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "  Could not scan for Edge shortcuts in $location" -ForegroundColor Yellow
        }
    }
}

# Remove Edge from taskbar pinned items (requires additional registry cleanup)
Write-Host "Removing Edge from taskbar..."
$taskbarPinPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (Test-Path $taskbarPinPath) {
    Get-ChildItem -Path $taskbarPinPath -Filter "*Edge*" | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Clean registry entries
Write-Host "Cleaning registry entries..."
$edgeRegKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate",
    "HKCU:\Software\Microsoft\Edge",
    "HKCU:\Software\Microsoft\EdgeUpdate",
    "HKLM:\Software\Policies\Microsoft\Edge",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
    "HKCU:\Software\Classes\MSEdgeHTM",
    "HKLM:\SOFTWARE\Classes\MSEdgeHTM"
)

foreach ($regKey in $edgeRegKeys) {
    if (Test-Path $regKey) {
        try {
            Remove-Item -Path $regKey -Recurse -Force -ErrorAction Stop
            Write-Host "Removed registry key: $regKey" -ForegroundColor Green
        } catch {
            Write-Host "Failed to remove registry key $regKey : $_" -ForegroundColor Yellow
        }
    }
}

# Clean Windows Search index for Edge
Write-Host "Cleaning Windows Search index..."
try {
    $searchPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\UsrClass.dat",
        "$env:APPDATA\Microsoft\Windows\Recent\*Edge*"
    )
    
    foreach ($searchPath in $searchPaths) {
        if (Test-Path $searchPath) {
            Remove-Item $searchPath -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
} catch {
    Write-Host "Could not clean all search index entries" -ForegroundColor Yellow
}

Write-Host "`nMicrosoft Edge removal completed!" -ForegroundColor Green
Write-Host "Summary of actions taken:" -ForegroundColor Cyan
Write-Host "- Stopped Edge processes" -ForegroundColor White
Write-Host "- Removed Edge packages and provisioned packages" -ForegroundColor White
Write-Host "- Deleted Edge installation directories" -ForegroundColor White
Write-Host "- Removed shortcuts from ALL common locations" -ForegroundColor White
Write-Host "- Cleaned registry entries" -ForegroundColor White
Write-Host "- Removed taskbar pins" -ForegroundColor White
Write-Host "`nNote: Windows Update may reinstall Edge in future updates." -ForegroundColor Yellow
Write-Host "Consider using Group Policy or registry tweaks to prevent reinstallation." -ForegroundColor Yellow

pause
