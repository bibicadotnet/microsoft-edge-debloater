param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("stable", "beta", "dev", "canary")]
    [string]$Channel = "stable"
)

if ($env:EDGE_CHANNEL) { $Channel = $env:EDGE_CHANNEL; $env:EDGE_CHANNEL = $null }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arg = if ($PSCommandPath) { "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Channel $Channel" }
           else { "-NoProfile -ExecutionPolicy Bypass -Command `"&{`$env:EDGE_CHANNEL='$Channel'; irm https://go.bibica.net/edge | iex}`"" }
    Start-Process powershell.exe $arg -Verb RunAs
    exit
}

Stop-Process -Name msedge,MicrosoftEdgeUpdate,edgeupdate,edgeupdatem,MicrosoftEdgeSetup -Force -ErrorAction SilentlyContinue
Clear-Host

$channelDisplay = $Channel.Substring(0,1).ToUpper() + $Channel.Substring(1).ToLower()
Write-Host " Microsoft Edge $channelDisplay Browser Installer " -BackgroundColor DarkGreen

$edgePath = @{
    "stable" = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    "beta" = "C:\Program Files (x86)\Microsoft\Edge Beta\Application\msedge.exe"
    "dev" = "C:\Program Files (x86)\Microsoft\Edge Dev\Application\msedge.exe"
    "canary" = "C:\Users\$env:USERNAME\AppData\Local\Microsoft\Edge SxS\Application\msedge.exe"
}[$Channel]

$current = if (Test-Path $edgePath) { (Get-Item $edgePath).VersionInfo.ProductVersion } else { "Not Installed" }
$latest = ((irm https://edgeupdates.microsoft.com/api/products).Where({ $_.Product -eq $channelDisplay }).Releases |
    Where-Object { $_.Platform -eq "Windows" -and $_.Architecture -eq "x64" } |
    Sort-Object PublishedTime -Descending)[0].ProductVersion

Write-Host "`nCurrent Edge $channelDisplay version : $current" -ForegroundColor Yellow
Write-Host "Latest Edge $channelDisplay version  : $latest" -ForegroundColor Green
Write-Host "`nStarting download and installation..." -ForegroundColor Cyan

$tempDir = "$env:USERPROFILE\Downloads\microsoft-edge-debloater"
if (-not (Test-Path $tempDir)) { New-Item $tempDir -ItemType Directory | Out-Null }

$installer = "$tempDir\MicrosoftEdgeSetup.exe"
(New-Object Net.WebClient).DownloadFile("https://go.microsoft.com/fwlink/?linkid=2109047&Channel=$channelDisplay&language=en", $installer)
Start-Process $installer "/silent /install" -Wait

Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
Stop-Process -Name msedge,MicrosoftEdgeUpdate,edgeupdate,edgeupdatem,MicrosoftEdgeSetup -Force -ErrorAction SilentlyContinue

$edgeCorePath = if ($Channel -eq "canary") { "C:\Users\$env:USERNAME\AppData\Local\Microsoft" } else { "C:\Program Files (x86)\Microsoft" }
Remove-Item "$edgeCorePath\EdgeCore", "$edgeCorePath\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue

$regFile = "$tempDir\debloat.reg"
(New-Object Net.WebClient).DownloadFile("https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/main/vi.edge.reg", $regFile)
Start-Process regedit "/s `"$regFile`"" -Wait -NoNewWindow

Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge $channelDisplay Browser installation completed!" -ForegroundColor Green
Write-Host "`nAutomatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "`nNOTICE: To update Microsoft Edge $channelDisplay when needed, please:" -ForegroundColor Cyan -BackgroundColor DarkGreen
Write-Host "1. Open PowerShell with Administrator privileges" -ForegroundColor White
$updateCommand = if ($Channel -eq "stable") { "irm https://go.bibica.net/edge | iex" } else { "`$env:EDGE_CHANNEL='$Channel'; irm https://go.bibica.net/edge | iex" }
Write-Host "2. Run the following command: " -ForegroundColor Yellow -NoNewline
Write-Host $updateCommand -ForegroundColor Red
Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
Write-Host
