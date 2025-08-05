$ProgressPreference = 'SilentlyContinue'
# Check admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting as administrator..." -ForegroundColor Red
    if ([string]::IsNullOrEmpty($PSCommandPath)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/edge_disable_update | iex`"" -Verb RunAs
    } else {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    }
    exit
}

# Stop Microsoft Edge processes
@("msedge", "MicrosoftEdgeUpdate", "edgeupdate", "edgeupdatem", "MicrosoftEdgeSetup") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}

Clear-Host
Write-Host " Microsoft Edge Browser Installer " -BackgroundColor DarkGreen

$folder = "$env:USERPROFILE\Downloads\EdgeInstall"
New-Item -ItemType Directory -Path $folder -Force | Out-Null
try {
    Write-Host "Getting latest Microsoft Edge Stable ..." -ForegroundColor Yellow
    $release = Invoke-RestMethod "https://api.github.com/repos/bibicadotnet/edge_installer/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*X64*" }
    
    if ($asset) {
        $installer = "$folder\$($asset.name)"
        Write-Host "Downloading $($release.tag_name) ($([math]::Round($asset.size/1MB, 2))MB)..."
        (New-Object System.Net.WebClient).DownloadFile($asset.browser_download_url, $installer)
        
        Write-Host "Installing..." -ForegroundColor Green
        Start-Process $installer -ArgumentList "--system-level --do-not-launch-chrome" -Wait -NoNewWindow
        
        Write-Host "Applying policies..." -ForegroundColor Cyan
        @(
            "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/restore-default.reg",
            "https://raw.githubusercontent.com/bibicadotnet/microsoft-edge-debloater/refs/heads/main/vi.edge.reg"
        ) | ForEach-Object {
            $regFile = "$folder\$(Split-Path $_ -Leaf)"
            Invoke-WebRequest $_ -OutFile $regFile -UseBasicParsing
            Start-Process "regedit.exe" "/s `"$regFile`"" -Wait -NoNewWindow
        }
        
        # Remove scheduled tasks
        Write-Host "Applying disabled updates..." -ForegroundColor Cyan
        Get-ScheduledTask -TaskName "MicrosoftEdgeUpdate*" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        # Disable updater executables
        Get-Item "${env:ProgramFiles}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe", "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -ErrorAction SilentlyContinue | ForEach-Object {
            Get-Process -Name $_.BaseName -ErrorAction SilentlyContinue | Stop-Process -Force
            $disabled = $_.FullName + ".disabled"
            Rename-Item -Path $_.FullName -NewName $disabled -Force -ErrorAction SilentlyContinue
            New-Item -Path $_.FullName -ItemType File -Force | Out-Null
            (Get-Item $_.FullName -ErrorAction SilentlyContinue).Attributes = "ReadOnly, Hidden, System"
        }
        
        Write-Host "Installation completed!" -ForegroundColor Green
    } else {
        Write-Host "Installer not found!" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Clean up
# Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nMicrosoft Edge Browser installation completed!" -ForegroundColor Green
Write-Host "`nAutomatic updates are completely disabled." -ForegroundColor Yellow
Write-Host "Recommendation: Restart your computer to apply all changes." -ForegroundColor Yellow

Write-Host "`nNOTICE: To update Microsoft Edge when needed, please:" -ForegroundColor Cyan -BackgroundColor DarkGreen
Write-Host "1. Open PowerShell with Administrator privileges" -ForegroundColor White
Write-Host "2. Run the following command: irm https://go.bibica.net/edge_disable_update | iex" -ForegroundColor Yellow
Write-Host "3. Wait for the installation process to complete" -ForegroundColor White
Write-Host
