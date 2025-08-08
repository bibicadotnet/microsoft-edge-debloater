param(
    [switch]$beta,
    [switch]$dev,
    [switch]$canary
)

# Determine channel
$Channel = "stable"
if ($beta) { $Channel = "beta" }
elseif ($dev) { $Channel = "dev" }
elseif ($canary) { $Channel = "canary" }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting as administrator..." -ForegroundColor Red
    $arg = if ([string]::IsNullOrEmpty($PSCommandPath)) {
        $switchArg = ""
        if ($beta) { $switchArg = " -beta" }
        elseif ($dev) { $switchArg = " -dev" }
        elseif ($canary) { $switchArg = " -canary" }
        "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/edge | iex$switchArg`""
    } else {
        $switchArg = ""
        if ($beta) { $switchArg = " -beta" }
        elseif ($dev) { $switchArg = " -dev" }
        elseif ($canary) { $switchArg = " -canary" }
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$switchArg"
    }
    Start-Process powershell.exe $arg -Verb RunAs
    exit
}

# Kill processes
Stop-Process -Name msedge,MicrosoftEdgeUpdate,edgeupdate,edgeupdatem,MicrosoftEdgeSetup -Force -ErrorAction SilentlyContinue
Clear-Host

$channelDisplay = $Channel.Substring(0,1).ToUpper() + $Channel.Substring(1).ToLower()
Write-Host " Microsoft Edge Browser Installer ($channelDisplay) " -BackgroundColor DarkGreen

$current = "Not Installed"
$edgePath = switch ($Channel) {
    "stable" { "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" }
    "beta" { "C:\Program Files (x86)\Microsoft\Edge Beta\Application\msedge.exe" }
    "dev" { "C:\Program Files (x86)\Microsoft\Edge Dev\Application\msedge.exe" }
    "canary" { "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Edge SxS\Application\msedge.exe" }
}

if (Test-Path $edgePath) {
    $current = (Get-Item $edgePath).VersionInfo.ProductVersion
}

$latest = ((irm https://edgeupdates.microsoft.com/api/products).Where({ $_.Product -eq $channelDisplay }).Releases |
    Where-Object { $_.Platform -eq "Windows" -and $_.Architecture -eq "x64" } |
    Sort-Object PublishedTime -Descending)[0].ProductVersion

Write-Host "`nCurrent Edge $channelDisplay version : $current" -ForegroundColor Yellow
Write-Host "Latest $channelDisplay Edge version  : $latest" -ForegroundColor Green
Write-Host "`nStarting download and installation..." -ForegroundColor Cyan

# Create temp folder
$tempDir = "$env:USERPROFILE\Downloads\microsoft-edge-debloater"
if (-not (Test-Path $tempDir)) { New-Item $tempDir -ItemType Directory | Out-Null }

# Download & install
$installer="$tempDir\MicrosoftEdgeSetup.exe"
$downloadUrl = "https://go.microsoft.com/fwlink/?linkid=2109047&Channel=$channelDisplay&language=en"
$wc=New-Object Net.WebClient
try{$wc.DownloadFile($downloadUrl,$installer)}finally{$wc.Dispose()}
Start-Process $installer "/silent /install" -Wait

# Remove scheduled tasks
Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# Remove EdgeUpdate & EdgeCore
Stop-Process -Name msedge,MicrosoftEdgeUpdate,edgeupdate,edgeupdatem,MicrosoftEdgeSetup -Force -ErrorAction SilentlyContinue
if ($Channel -eq "canary") {
    Remove-Item "C:\Users\$env:USERNAME\AppData\Local\Microsoft\EdgeCore","C:\Users\$env:USERNAME\AppData\Local\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Remove-Item "C:\Program Files (x86)\Microsoft\EdgeCore","C:\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue
}

# Apply registry tweaks
$regUrl="https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/vi.edge.reg"
$regFile="$tempDir\debloat.reg"
$wc=New-Object Net.WebClient
try{$wc.DownloadFile($regUrl,$regFile)}finally{$wc.Dispose()}
Start-Process regedit "/s `"$regFile`"" -Wait -NoNewWindow

# Clean up
#Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge Browser installation completed!" -ForegroundColor Green
Write-Host "`nAutomatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow

Write-Host "`nNOTICE: To update Microsoft Edge when needed, please:" -ForegroundColor Cyan -BackgroundColor DarkGreen
Write-Host "1. Open PowerShell with Administrator privileges" -ForegroundColor White
$updateCommand = switch ($Channel) {
    "stable" { "irm https://go.bibica.net/edge | iex" }
    "beta" { "irm https://go.bibica.net/edge | iex --beta" }
    "dev" { "irm https://go.bibica.net/edge | iex --dev" }
    "canary" { "irm https://go.bibica.net/edge | iex --canary" }
}
Write-Host "2. Run the following command: $updateCommand" -ForegroundColor Yellow
Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
Write-Host
