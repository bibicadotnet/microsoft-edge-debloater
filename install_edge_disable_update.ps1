if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting as administrator..." -ForegroundColor Red
    if ([string]::IsNullOrEmpty($PSCommandPath)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/edge_disable_update | iex`"" -Verb RunAs
    } else {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    exit
}

# Kill processes
@("msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Clear-Host
Write-Host " Microsoft Edge Browser Installer " -BackgroundColor DarkGreen

$json = Invoke-RestMethod "https://edgeupdates.microsoft.com/api/products" -UseBasicParsing
$stableProduct = $json | Where-Object { $_.Product -eq "Stable" }
$filtered = $stableProduct.Releases | Where-Object {
    $_.Platform -eq "Windows" -and $_.Architecture -eq "x64"
}
$latest = $filtered | Sort-Object PublishedTime -Descending | Select-Object -First 1

Write-Host "`nLatest Stable Edge version  : $($latest.ProductVersion)"

Write-Host "`nStarting download and installation..." -ForegroundColor Cyan

# Create temp folder
$tempDir = "$env:TEMP\EdgeInstall_$(Get-Random)"
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

# Download & install
$installer = "$tempDir\MicrosoftEdgeSetup.exe"
$webClient = New-Object System.Net.WebClient
try {
    $webClient.DownloadFile("https://go.microsoft.com/fwlink/?linkid=2109047&Channel=Stable&language=en", $installer)
}
finally {
    $webClient.Dispose()
}
Start-Process -FilePath $installer -ArgumentList "/silent /install" -Wait

# Remove scheduled tasks
Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# Disable updater executables
Get-Item "${env:ProgramFiles}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe", "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Process -Name $_.BaseName -ErrorAction SilentlyContinue | Stop-Process -Force
    $disabled = $_.FullName + ".disabled"
    Rename-Item -Path $_.FullName -NewName $disabled -Force -ErrorAction SilentlyContinue
    New-Item -Path $_.FullName -ItemType File -Force | Out-Null
    (Get-Item $_.FullName -ErrorAction SilentlyContinue).Attributes = "ReadOnly, Hidden, System"
}

# Apply registry tweaks
@(
    @{ "name" = "restore"; "url" = "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/restore-default.reg" },
    @{ "name" = "debloat"; "url" = "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/vi.edge.reg" }
) | ForEach-Object {
    try {
        $regFile = "$tempDir\$($_.name).reg"
        $webClient = New-Object System.Net.WebClient
        try {
            $webClient.DownloadFile($_.url, $regFile)
        }
        finally {
            $webClient.Dispose()
        }
        Start-Process "regedit.exe" -ArgumentList "/s `"$regFile`"" -Wait -NoNewWindow
    }
    catch { }
}

# Clean up
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge Browser installation completed!" -ForegroundColor Green
Write-Host "`nAutomatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow

Write-Host "`nNOTICE: To update Microsoft Edge when needed, please:" -ForegroundColor Cyan -BackgroundColor DarkGreen
Write-Host "1. Open PowerShell with Administrator privileges" -ForegroundColor White
Write-Host "2. Run the following command: irm https://go.bibica.net/edge_disable_update | iex" -ForegroundColor Yellow
Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
Write-Host
