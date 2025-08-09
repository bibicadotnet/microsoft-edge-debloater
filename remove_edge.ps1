# Remove Microsoft Edge (requires Admin)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Run this script as Administrator!" -ForegroundColor Red; pause; exit
}
Write-Host "`nRemoving Microsoft Edge..." -ForegroundColor Yellow

# Stop Edge processes
"msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup" | 
    ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

# Remove directories  
@(
    "${env:ProgramFiles(x86)}\Microsoft\Edge",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Beta", 
    "${env:ProgramFiles(x86)}\Microsoft\Edge Dev",
    "${env:ProgramFiles(x86)}\Microsoft\Edge Canary",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeCore",
    "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate",
    "${env:LOCALAPPDATA}\Microsoft\EdgeUpdate",
    "${env:LOCALAPPDATA}\Microsoft\EdgeCore", 
    "${env:LOCALAPPDATA}\Microsoft\Edge SxS\Application"
) | ForEach-Object { if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue } }

# Remove shortcuts
$edgeVariants = "Microsoft Edge", "Microsoft Edge Beta", "Microsoft Edge Dev", "Microsoft Edge Canary"
$locations = @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory"), 
    [Environment]::GetFolderPath("Programs"),
    [Environment]::GetFolderPath("CommonPrograms"),
    (Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "Microsoft")
)
$edgeVariants | ForEach-Object {
    $name = $_
    $locations | ForEach-Object {
        $path = Join-Path $_ "$name.lnk"
        if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
    }
}

# Remove registry entries
@(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate",
    "HKCU:\Software\Microsoft\Edge",
    "HKCU:\Software\Microsoft\EdgeUpdate", 
    "HKLM:\Software\Policies\Microsoft\Edge",
    "HKLM:\Software\Policies\Microsoft\EdgeUpdate"
) | ForEach-Object { if (Test-Path $_) { Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue } }

# Remove StartMenuInternet entries
@(
    "HKLM:\SOFTWARE\Clients\StartMenuInternet",
    "HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet", 
    "HKCU:\SOFTWARE\Clients\StartMenuInternet"
) | ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem $_ | Where-Object { $_.Name -like "*Microsoft Edge*" } | 
        ForEach-Object { Remove-Item $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Clean uninstall entries
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall", 
"HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
ForEach-Object {
    if (Test-Path $_) {
        Get-ChildItem $_ -ErrorAction SilentlyContinue | Where-Object {
            $displayName = (Get-ItemProperty $_.PsPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
            $displayName -and $displayName -like "*Microsoft Edge*"
        } | ForEach-Object { Remove-Item $_.PsPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Clean EdgeUpdate clients
"HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients",
"HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients" |
ForEach-Object {
    if (Test-Path $_) {
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Remove services
"edgeupdate", "edgeupdatem", "MicrosoftEdgeUpdate" |
    ForEach-Object { if (Get-Service -Name $_ -ErrorAction SilentlyContinue) { sc.exe delete $_ | Out-Null } }

Write-Host "Microsoft Edge has been removed." -ForegroundColor Green
Write-Host
