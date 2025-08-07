if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting as administrator..." -ForegroundColor Red
    $arg = if ([string]::IsNullOrEmpty($PSCommandPath)) {
        "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/edge_disable_update | iex`""
    } else {
        "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    }
    Start-Process powershell.exe $arg -Verb RunAs
    exit
}

# Kill processes
@("msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Clear-Host
Write-Host " Microsoft Edge Browser Installer " -BackgroundColor DarkGreen

$current = "Not Installed"
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (Test-Path $edgePath) {
    $current = (Get-Item $edgePath).VersionInfo.ProductVersion
}

$latest = ((irm https://edgeupdates.microsoft.com/api/products).Where({ $_.Product -eq "Stable" }).Releases |
    Where-Object { $_.Platform -eq "Windows" -and $_.Architecture -eq "x64" } |
    Sort-Object PublishedTime -Descending)[0].ProductVersion

Write-Host "`nCurrent Edge version        : $current" -ForegroundColor Yellow
Write-Host "Latest Stable Edge version  : $latest" -ForegroundColor Green
Write-Host "`nStarting download and installation..." -ForegroundColor Cyan

# Create temp folder
$tempDir = "$env:USERPROFILE\Downloads\microsoft-edge-debloater"
if (-not (Test-Path $tempDir)) { New-Item $tempDir -ItemType Directory | Out-Null }

# Remove bypass upload if have
$h="$env:WINDIR\System32\drivers\etc\hosts"; (Get-Content $h) | Where-Object {$_ -notmatch "msedge.api.cdp.microsoft.com"} | Set-Content $h

# Download & install
$installer="$tempDir\MicrosoftEdgeSetup.exe"
$wc=New-Object Net.WebClient
try{$wc.DownloadFile("https://go.microsoft.com/fwlink/?linkid=2109047&Channel=Stable&language=en",$installer)}finally{$wc.Dispose()}
Start-Process $installer "/silent /install" -Wait

# Remove scheduled tasks
Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# Bypass update by hosts
cmd /c "FIND /C /I `"msedge.api.cdp.microsoft.com`" `"$env:WINDIR\system32\drivers\etc\hosts`"" | Out-Null; if ($LASTEXITCODE -ne 0) { Add-Content "$env:WINDIR\system32\drivers\etc\hosts" "`n0.0.0.0                   msedge.api.cdp.microsoft.com" }

# Remove EdgeUpdate
@("msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Remove-Item "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction SilentlyContinue

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
Write-Host "2. Run the following command: irm https://go.bibica.net/edge_disable_update | iex" -ForegroundColor Yellow
Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
Write-Host
