# Remove Microsoft Edge (requires Admin)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Run this script as Administrator!" -ForegroundColor Red; pause; exit
}
Write-Host "`nRemoving Microsoft Edge..." -ForegroundColor Yellow

# Stop Edge-related processes
"msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup" | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Delete Edge install directories
@(
    "${env:ProgramFiles(x86)}\Microsoft\Edge",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Beta",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Dev",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Canary",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeCore",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\EdgeUpdate",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\EdgeCore",
    "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Edge SxS\Application"
) | ForEach-Object {
    if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
}

$shortcutNames = @(
    "Microsoft Edge",
    "Microsoft Edge Beta",
    "Microsoft Edge Dev",
    "Microsoft Edge Canary"
)

$commonProgramsMicrosoft = Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "Microsoft"

$locations = @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory"),
    [Environment]::GetFolderPath("Programs"),
    [Environment]::GetFolderPath("CommonPrograms"),
    $commonProgramsMicrosoft
)

foreach ($name in $shortcutNames) {
    foreach ($location in $locations) {
        $path = Join-Path $location "$name.lnk"
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }
}

# Remove Edge registry entries
@(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate",
    "HKCU:\Software\Microsoft\Edge",
    "HKCU:\Software\Microsoft\EdgeUpdate",
    "HKLM:\Software\Policies\Microsoft\Edge",
    "HKLM:\Software\Policies\Microsoft\EdgeUpdate"    
) | ForEach-Object {
    if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue }
}

# Remove any uninstall registry entries with 'Microsoft Edge' in DisplayName (all scopes)
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients"
)

foreach ($path in $uninstallPaths) {
    if (Test-Path $path) {
        Get-ChildItem $path | ForEach-Object {
            $props = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -like "*Microsoft Edge*") {
                Remove-Item $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# Remove Edge Update services if they exist
$services = "edgeupdate", "edgeupdatem", "MicrosoftEdgeUpdate"
foreach ($svc in $services) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        sc.exe delete $svc | Out-Null
    }
}

# Remove EdgeUpdate folder
Remove-Item "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Microsoft Edge has been removed." -ForegroundColor Green
Write-Host
