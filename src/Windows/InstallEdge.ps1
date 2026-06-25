#requires -Version 5.1

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("stable", "beta", "dev", "canary")]
    [string]$Channel = "stable"
)

if ($env:EDGE_CHANNEL) { $Channel = $env:EDGE_CHANNEL; $env:EDGE_CHANNEL = $null }

function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Restart-AsAdministrator {
    param([string]$RequestedChannel)

    if (-not $PSCommandPath) { throw "Cannot restart as administrator without a script path." }
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Channel $RequestedChannel"
    Start-Process powershell.exe $arguments -Verb RunAs
    exit
}

function Get-EdgeChannelDisplayName {
    param([string]$RequestedChannel)
    return $RequestedChannel.Substring(0, 1).ToUpper() + $RequestedChannel.Substring(1).ToLower()
}

function Get-EdgeExecutablePath {
    param([string]$RequestedChannel)

    return @{
        "stable" = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        "beta" = "C:\Program Files (x86)\Microsoft\Edge Beta\Application\msedge.exe"
        "dev" = "C:\Program Files (x86)\Microsoft\Edge Dev\Application\msedge.exe"
        "canary" = "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Edge SxS\Application\msedge.exe"
    }[$RequestedChannel]
}

function Get-InstalledEdgeVersion {
    param([string]$RequestedChannel)

    $edgePath = Get-EdgeExecutablePath $RequestedChannel
    if (Test-Path $edgePath) { return (Get-Item $edgePath).VersionInfo.ProductVersion }
    return "Not Installed"
}

function Get-LatestWindowsEdgeVersion {
    param([string]$ChannelDisplayName)

    return ((Invoke-RestMethod https://edgeupdates.microsoft.com/api/products).Where({ $_.Product -eq $ChannelDisplayName }).Releases |
        Where-Object { $_.Platform -eq "Windows" -and $_.Architecture -eq "x64" } |
        Sort-Object PublishedTime -Descending)[0].ProductVersion
}

function Stop-EdgeProcesses {
    Stop-Process -Name msedge,MicrosoftEdgeUpdate,edgeupdate,edgeupdatem,MicrosoftEdgeSetup -Force -ErrorAction SilentlyContinue
}

function New-EdgeTempDirectory {
    $tempDir = "$env:USERPROFILE\Downloads\microsoft-edge-debloater"
    if (-not (Test-Path $tempDir)) { New-Item $tempDir -ItemType Directory | Out-Null }
    return $tempDir
}

function Save-File {
    param([string]$Url, [string]$Path)
    (New-Object Net.WebClient).DownloadFile($Url, $Path)
}

function Install-EdgeSetup {
    param([string]$ChannelDisplayName, [string]$TempDir)

    $installer = Join-Path $TempDir "MicrosoftEdgeSetup.exe"
    Save-File "https://go.microsoft.com/fwlink/?linkid=2109047&Channel=$ChannelDisplayName&language=en" $installer
    Start-Process $installer "/silent /install" -Wait
}

function Remove-EdgeCore {
    param([string]$RequestedChannel)

    $edgeCoreRoot = if ($RequestedChannel -eq "canary") { "C:\Users\$env:USERNAME\AppData\Local\Microsoft" } else { "C:\Program Files (x86)\Microsoft" }
    Remove-Item (Join-Path $edgeCoreRoot "EdgeCore") -Recurse -Force -ErrorAction SilentlyContinue
}

function Import-RegistryFile {
    param([string]$Path)
    Start-Process regedit "/s `"$Path`"" -Wait -NoNewWindow
}

function Apply-BrowserPolicies {
    param([string]$TempDir)

    $regFile = Join-Path $TempDir "debloat.reg"
    Save-File "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/main/policies/windows/edge-browser-debloat.reg" $regFile
    Import-RegistryFile $regFile
}

function Apply-EdgeUpdatePolicies {
    param([string]$TempDir)

    $updateRegFile = Join-Path $TempDir "edge-update-disable.reg"
    Save-File "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/main/policies/windows/edge-update-disable.reg" $updateRegFile
    Import-RegistryFile $updateRegFile
}

function Write-UpdateInstructions {
    param([string]$RequestedChannel, [string]$ChannelDisplayName)

    Write-Host "`nMicrosoft Edge $ChannelDisplayName Browser installation completed!" -ForegroundColor Green
    Write-Host "`nAutomatic updates are completely disabled." -ForegroundColor Yellow
    Write-Host "`nNOTICE: To update Microsoft Edge $ChannelDisplayName when needed, please:" -ForegroundColor Cyan -BackgroundColor DarkGreen
    Write-Host "1. Open PowerShell with Administrator privileges" -ForegroundColor White
    $updateCommand = "pwsh ./Invoke-EdgeDebloat.ps1 -Action Install -Channel $RequestedChannel"
    Write-Host "2. Run the following command: " -ForegroundColor Yellow -NoNewline
    Write-Host $updateCommand -ForegroundColor Red
    Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
    Write-Host
}

function Install-Edge {
    param([string]$RequestedChannel)

    if (-not (Test-Administrator)) { Restart-AsAdministrator $RequestedChannel }

    Stop-EdgeProcesses
    Clear-Host

    $channelDisplayName = Get-EdgeChannelDisplayName $RequestedChannel
    Write-Host " Microsoft Edge $channelDisplayName Browser Installer " -BackgroundColor DarkGreen
    Write-Host "`nCurrent Edge $channelDisplayName version : $(Get-InstalledEdgeVersion $RequestedChannel)" -ForegroundColor Yellow
    Write-Host "Latest Edge $channelDisplayName version  : $(Get-LatestWindowsEdgeVersion $channelDisplayName)" -ForegroundColor Green
    Write-Host "`nStarting download and installation..." -ForegroundColor Cyan

    $tempDir = New-EdgeTempDirectory
    Install-EdgeSetup $channelDisplayName $tempDir
    Stop-EdgeProcesses
    Remove-EdgeCore $RequestedChannel
    Apply-BrowserPolicies $tempDir
    Apply-EdgeUpdatePolicies $tempDir
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-UpdateInstructions $RequestedChannel $channelDisplayName
}

Install-Edge $Channel
