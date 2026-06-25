#requires -Version 5.1

function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    if (Test-Administrator) { return }
    Write-Host "Run this script as Administrator!" -ForegroundColor Red
    pause
    exit
}

function Stop-EdgeProcesses {
    "msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup" |
        ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
}

function Remove-ExistingPath {
    param([string]$Path)
    if (Test-Path $Path) { Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue }
}

function Remove-EdgeDirectories {
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
    ) | ForEach-Object { Remove-ExistingPath $_ }
}

function Remove-EdgeShortcuts {
    $edgeVariants = "Microsoft Edge", "Microsoft Edge Beta", "Microsoft Edge Dev", "Microsoft Edge Canary"
    $locations = @(
        [Environment]::GetFolderPath("Desktop"),
        [Environment]::GetFolderPath("CommonDesktopDirectory"),
        [Environment]::GetFolderPath("Programs"),
        [Environment]::GetFolderPath("CommonPrograms"),
        (Join-Path ([Environment]::GetFolderPath("CommonPrograms")) "Microsoft")
    )

    $edgeVariants | ForEach-Object {
        $edgeName = $_
        $locations | ForEach-Object {
            $shortcutPath = Join-Path $_ "$edgeName.lnk"
            if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force -ErrorAction SilentlyContinue }
        }
    }
}

function Remove-EdgePolicyAndProfileRegistry {
    @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge",
        "HKCU:\Software\Microsoft\Edge",
        "HKLM:\Software\Policies\Microsoft\Edge"
    ) | ForEach-Object { Remove-ExistingPath $_ }
}

function Remove-StartMenuInternetEntries {
    @(
        "HKLM:\SOFTWARE\Clients\StartMenuInternet",
        "HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet",
        "HKCU:\SOFTWARE\Clients\StartMenuInternet"
    ) | ForEach-Object {
        if (Test-Path $_) {
            Get-ChildItem $_ | Where-Object { $_.Name -like "*Microsoft Edge*" } |
                ForEach-Object { Remove-ExistingPath $_.PsPath }
        }
    }
}

function Remove-UninstallEntries {
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
        ForEach-Object {
            if (Test-Path $_) {
                Get-ChildItem $_ -ErrorAction SilentlyContinue | Where-Object {
                    $displayName = (Get-ItemProperty $_.PsPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
                    $displayName -and $displayName -like "*Microsoft Edge*"
                } | ForEach-Object { Remove-ExistingPath $_.PsPath }
            }
        }
}

function Remove-WindowsInstallerEntries {
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData",
    "HKLM:\SOFTWARE\Classes\Installer\Products",
    "HKLM:\SOFTWARE\Classes\Installer\Features",
    "HKLM:\SOFTWARE\Classes\Installer\UpgradeCodes" |
        ForEach-Object {
            if (Test-Path $_) {
                Get-ChildItem $_ -Recurse -ErrorAction SilentlyContinue | Where-Object {
                    $properties = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue
                    ($properties.ProductName -like "*Microsoft Edge*") -or ($properties.DisplayName -like "*Microsoft Edge*")
                } | ForEach-Object { Remove-ExistingPath $_.PsPath }
            }
        }
}

function Remove-RegisteredApplications {
    $registeredApplicationsPath = "HKLM:\SOFTWARE\RegisteredApplications"
    if (-not (Test-Path $registeredApplicationsPath)) { return }

    Get-ItemProperty $registeredApplicationsPath -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty |
        Where-Object { $_.Name -like "*Microsoft Edge*" } |
        ForEach-Object { Remove-ItemProperty -Path $registeredApplicationsPath -Name $_.Name -ErrorAction SilentlyContinue }
}

function Remove-EdgeUpdateTasks {
    Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue |
        Unregister-ScheduledTask -Confirm:$false
}

function Remove-Edge {
    Assert-Administrator
    Write-Host "`nRemoving Microsoft Edge v1.0..." -ForegroundColor Yellow
    Stop-EdgeProcesses
    Remove-EdgeDirectories
    Remove-EdgeShortcuts
    Remove-EdgePolicyAndProfileRegistry
    Remove-StartMenuInternetEntries
    Remove-UninstallEntries
    Remove-WindowsInstallerEntries
    Remove-RegisteredApplications
    Remove-EdgeUpdateTasks
    Write-Host "Microsoft Edge has been removed." -ForegroundColor Green
    Write-Host
}

Remove-Edge
