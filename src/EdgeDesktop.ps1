#requires -Version 5.1

param(
    [ValidateSet("Versions", "SelectInstaller", "Download", "Install", "SelfTest")]
    [string]$Action = "Versions",

    [ValidateSet("Stable", "Beta", "Dev", "Canary")]
    [string]$Channel = "Stable",

    [ValidateSet("Windows", "MacOS", "Linux", "iOS", "Android", "Auto")]
    [string]$Platform = "Auto",

    [string]$Architecture = "Auto",

    [ValidateSet("auto", "pkg", "msi", "deb", "rpm")]
    [string]$Package = "auto",

    [string]$DownloadDir = "downloads",

    [switch]$Json,

    [string]$ApiUrl = "https://edgeupdates.microsoft.com/api/products"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Channels = @("Stable", "Beta", "Dev", "Canary")
$Platforms = @("Windows", "MacOS", "Linux", "iOS", "Android")

function Get-EdgeProducts {
    param([string]$Url)
    return Invoke-RestMethod -Uri $Url -UseBasicParsing
}

function Get-CurrentEdgePlatform {
    $os = [System.Environment]::OSVersion.Platform.ToString()
    if ($os -match "Win") { return "Windows" }
    if ($os -eq "Unix") {
        if (Test-Path -LiteralPath "/System/Library/CoreServices/SystemVersion.plist") { return "MacOS" }
        return "Linux"
    }
    throw "Unsupported desktop platform: $os"
}

function Get-CurrentEdgeArchitecture {
    if ((Get-CurrentEdgePlatform) -eq "Windows") {
        $machine = $env:PROCESSOR_ARCHITEW6432
        if (-not $machine) { $machine = $env:PROCESSOR_ARCHITECTURE }
    } else {
        $machine = (& uname -m)
    }
    $machine = ([string]$machine).ToLowerInvariant()
    if ($machine -eq "amd64" -or $machine -eq "x86_64") { return "x64" }
    if ($machine -eq "aarch64") { return "arm64" }
    if ($machine -eq "x64") { return "x64" }
    if ($machine -eq "arm64") { return "arm64" }
    if ($machine -eq "x86" -or $machine -eq "i386" -or $machine -eq "i686") { return "x86" }
    return $machine
}

function Get-PublishedTime {
    param($Release)
    if ($Release.PublishedTime -is [DateTimeOffset]) { return $Release.PublishedTime }
    if ($Release.PublishedTime -is [DateTime]) { return [DateTimeOffset]$Release.PublishedTime }
    return [DateTimeOffset]::Parse([string]$Release.PublishedTime)
}

function Get-LatestVersionMatrix {
    param($Products)

    $matrix = [ordered]@{}
    foreach ($channelName in $Channels) {
        $row = [ordered]@{}
        foreach ($platformName in $Platforms) {
            $row[$platformName] = ""
        }
        $matrix[$channelName] = $row
    }

    foreach ($product in $Products) {
        $channelName = [string]$product.Product
        if (-not $matrix.Contains($channelName)) { continue }
        foreach ($platformName in $Platforms) {
            $matches = @($product.Releases | Where-Object { $_.Platform -eq $platformName -and $_.ProductVersion })
            if ($matches.Count -gt 0) {
                $latest = $matches | Sort-Object { Get-PublishedTime $_ } -Descending | Select-Object -First 1
                $matrix[$channelName][$platformName] = [string]$latest.ProductVersion
            }
        }
    }

    return $matrix
}

function Write-VersionMarkdown {
    param($Matrix)

    "| Channel | Windows | macOS | Linux | iOS | Android |"
    "| --- | --- | --- | --- | --- | --- |"
    foreach ($channelName in $Channels) {
        $values = foreach ($platformName in $Platforms) {
            $value = $Matrix[$channelName][$platformName]
            if ($value) { $value } else { "not listed" }
        }
        "| $channelName | $($values -join ' | ') |"
    }
}

function Get-DefaultPackage {
    param([string]$PlatformName)

    if ($PlatformName -eq "MacOS") { return "pkg" }
    if ($PlatformName -eq "Windows") { return "msi" }
    if ($PlatformName -ne "Linux") { return $null }
    if (Test-Path -LiteralPath "/etc/os-release") {
        $text = (Get-Content -LiteralPath "/etc/os-release" -Raw).ToLowerInvariant()
        if ($text -match "fedora|rhel|centos|suse") { return "rpm" }
    }
    return "deb"
}

function Select-EdgeRelease {
    param($Products, [string]$ChannelName, [string]$PlatformName, [string]$Arch)

    $product = $Products | Where-Object { $_.Product -eq $ChannelName } | Select-Object -First 1
    if (-not $product) { throw "No $ChannelName product found" }

    $candidates = @($product.Releases | Where-Object { $_.Platform -eq $PlatformName })
    if ($candidates.Count -eq 0) { throw "No $ChannelName release found for $PlatformName/$Arch" }

    $archMatches = @($candidates | Where-Object { $_.Architecture -eq $Arch -or $_.Architecture -eq "universal" })
    if ($archMatches.Count -gt 0) {
        return $archMatches | Sort-Object { Get-PublishedTime $_ } -Descending | Select-Object -First 1
    }
    return $candidates | Sort-Object { Get-PublishedTime $_ } -Descending | Select-Object -First 1
}

function Select-EdgeArtifact {
    param($Release, [string]$PackageName)

    $artifacts = @($Release.Artifacts)
    if ($artifacts.Count -eq 0) { throw "No downloadable artifact listed for $($Release.Platform) $($Release.ProductVersion)" }

    if ($PackageName -and $PackageName -ne "auto") {
        $match = $artifacts | Where-Object { $_.ArtifactName -eq $PackageName } | Select-Object -First 1
        if ($match) { return $match }
        $names = ($artifacts | ForEach-Object { $_.ArtifactName }) -join ", "
        throw "No $PackageName artifact. Available: $names"
    }

    foreach ($name in @("pkg", "msi", "deb", "rpm")) {
        $match = $artifacts | Where-Object { $_.ArtifactName -eq $name } | Select-Object -First 1
        if ($match) { return $match }
    }
    return $artifacts[0]
}

function Select-EdgeInstaller {
    param($Products, [string]$ChannelName, [string]$PlatformName, [string]$Arch, [string]$PackageName)

    $release = Select-EdgeRelease $Products $ChannelName $PlatformName $Arch
    $artifactPackage = $PackageName
    if ($artifactPackage -eq "auto") {
        $artifactPackage = Get-DefaultPackage $PlatformName
    }
    $artifact = Select-EdgeArtifact $release $artifactPackage

    return [ordered]@{
        channel = $ChannelName
        platform = [string]$release.Platform
        architecture = [string]$release.Architecture
        version = [string]$release.ProductVersion
        artifact = [string]$artifact.ArtifactName
        url = [string]$artifact.Location
        sha256 = [string]$artifact.Hash
    }
}

function Get-FileNameFromUrl {
    param([string]$Url)
    return ([Uri]$Url).Segments[-1].Split("?")[0]
}

function Get-EdgeCommandName {
    param([string]$ChannelName)

    if ($ChannelName -eq "Stable") { return "microsoft-edge" }
    return "microsoft-edge-$($ChannelName.ToLowerInvariant())"
}

function Get-InstalledEdgeVersion {
    param([string]$ChannelName, [string]$PlatformName)

    if ($PlatformName -eq "MacOS") {
        $appName = if ($ChannelName -eq "Stable") { "Microsoft Edge" } else { "Microsoft Edge $ChannelName" }
        foreach ($root in @("/Applications", "$HOME/Applications")) {
            $plist = Join-Path $root "$appName.app/Contents/Info.plist"
            if (Test-Path -LiteralPath $plist) {
                return [string](& /usr/bin/plutil -extract CFBundleShortVersionString raw $plist 2>$null)
            }
        }
        return $null
    }

    if ($PlatformName -eq "Linux") {
        $command = Get-EdgeCommandName $ChannelName
        $executable = Get-Command $command -ErrorAction SilentlyContinue
        if ($executable) {
            $text = [string](& $command --version 2>$null)
            if ($text -match '([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)') { return $Matches[1] }
        }
        return $null
    }

    if ($PlatformName -eq "Windows") {
        $paths = @{
            Stable = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
            Beta = "C:\Program Files (x86)\Microsoft\Edge Beta\Application\msedge.exe"
            Dev = "C:\Program Files (x86)\Microsoft\Edge Dev\Application\msedge.exe"
            Canary = "$env:LOCALAPPDATA\Microsoft\Edge SxS\Application\msedge.exe"
        }
        $path = $paths[$ChannelName]
        if ($path -and (Test-Path -LiteralPath $path)) {
            return [string](Get-Item -LiteralPath $path).VersionInfo.ProductVersion
        }
    }

    return $null
}

function Test-VersionAtLeast {
    param([string]$Installed, [string]$Required)

    if (-not $Installed -or -not $Required) { return $false }
    try {
        return ([version]$Installed) -ge ([version]$Required)
    } catch {
        return $Installed -eq $Required
    }
}

function Test-InstallerHash {
    param($Selected, [string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    if (-not $Selected.sha256) { return $true }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
    return $actual -eq $Selected.sha256.ToUpperInvariant()
}

function Save-EdgeInstaller {
    param($Selected, [string]$TargetDir)

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    $path = Join-Path $TargetDir (Get-FileNameFromUrl $Selected.url)
    if (Test-InstallerHash $Selected $path) {
        return $path
    }
    Invoke-WebRequest -Uri $Selected.url -OutFile $path -UseBasicParsing
    if (-not (Test-InstallerHash $Selected $path)) {
        throw "SHA256 mismatch for $path"
    }
    return $path
}

function Install-EdgeInstaller {
    param([string]$Path, [string]$ArtifactName)

    if ($ArtifactName -eq "msi") {
        Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", $Path, "/qn") -Wait -NoNewWindow
        return
    }
    if ($ArtifactName -eq "pkg") {
        & sudo installer -pkg $Path -target /
        return
    }
    if ($ArtifactName -eq "deb") {
        & sudo dpkg -i $Path
        return
    }
    if ($ArtifactName -eq "rpm") {
        & sudo rpm -Uvh $Path
        return
    }
    throw "No install command for artifact type: $ArtifactName"
}

function Invoke-SelfTest {
    $sample = @(
        [pscustomobject]@{
            Product = "Stable"
            Releases = @(
                [pscustomobject]@{
                    Platform = "Windows"; Architecture = "x64"; ProductVersion = "2.0"; PublishedTime = "2026-01-02T00:00:00"; Artifacts = @([pscustomobject]@{ ArtifactName = "msi"; Location = "https://example.test/edge.msi"; Hash = "" })
                },
                [pscustomobject]@{
                    Platform = "Windows"; Architecture = "x64"; ProductVersion = "1.0"; PublishedTime = "2026-01-01T00:00:00"; Artifacts = @([pscustomobject]@{ ArtifactName = "msi"; Location = "https://example.test/old.msi"; Hash = "" })
                },
                [pscustomobject]@{
                    Platform = "MacOS"; Architecture = "universal"; ProductVersion = "1.5"; PublishedTime = "2026-01-01T00:00:00"; Artifacts = @([pscustomobject]@{ ArtifactName = "pkg"; Location = "https://example.test/edge.pkg"; Hash = "" })
                },
                [pscustomobject]@{
                    Platform = "Linux"; Architecture = "x64"; ProductVersion = "1.0"; PublishedTime = "2026-01-01T00:00:00"; Artifacts = @(
                        [pscustomobject]@{ ArtifactName = "rpm"; Location = "https://example.test/edge.rpm"; Hash = "" },
                        [pscustomobject]@{ ArtifactName = "deb"; Location = "https://example.test/edge.deb"; Hash = "" }
                    )
                }
            )
        },
        [pscustomobject]@{ Product = "EdgeUpdate"; Releases = @([pscustomobject]@{ Platform = "Windows"; ProductVersion = "9.9"; PublishedTime = "2026-01-03T00:00:00" }) }
    )

    $matrix = Get-LatestVersionMatrix $sample
    if ($matrix.Stable.Windows -ne "2.0") { throw "latest version selection failed" }
    if ($matrix.Stable.MacOS -ne "1.5") { throw "macOS version selection failed" }
    if ($matrix.Beta.Windows -ne "") { throw "unknown channel default failed" }
    $selected = Select-EdgeInstaller $sample "Stable" "Linux" "x64" "deb"
    if ($selected.artifact -ne "deb") { throw "artifact selection failed" }
    $mac = Select-EdgeInstaller $sample "Stable" "MacOS" "arm64" "auto"
    if ($mac.artifact -ne "pkg") { throw "universal macOS selection failed" }
    if (-not (Test-VersionAtLeast "149.0.4022.80" "149.0.4022.80")) { throw "version equality check failed" }
    if (-not (Test-VersionAtLeast "149.0.4022.81" "149.0.4022.80")) { throw "newer version check failed" }
    if (Test-VersionAtLeast "149.0.4022.79" "149.0.4022.80") { throw "older version check failed" }
}

if ($Action -eq "SelfTest") {
    Invoke-SelfTest
    exit 0
}

$targetPlatform = $Platform
if ($targetPlatform -eq "Auto") { $targetPlatform = Get-CurrentEdgePlatform }
$targetArch = $Architecture
if ($targetArch -eq "Auto") { $targetArch = Get-CurrentEdgeArchitecture }

$products = Get-EdgeProducts $ApiUrl

if ($Action -eq "Versions") {
    $matrix = Get-LatestVersionMatrix $products
    if ($Json) {
        $matrix | ConvertTo-Json -Depth 8
    } else {
        Write-VersionMarkdown $matrix
    }
    exit 0
}

$selected = Select-EdgeInstaller $products $Channel $targetPlatform $targetArch $Package
if ($Json) {
    $selected | ConvertTo-Json -Depth 6
} else {
    "$($selected.channel) $($selected.platform) $($selected.architecture) $($selected.version)"
    "$($selected.artifact): $($selected.url)"
    if ($selected.sha256) { "sha256: $($selected.sha256)" }
}

if ($Action -eq "SelectInstaller") {
    exit 0
}

if ($Action -eq "Install") {
    $installedVersion = Get-InstalledEdgeVersion $selected.channel $targetPlatform
    if (Test-VersionAtLeast $installedVersion $selected.version) {
        "installed: $installedVersion"
        "install skipped: $($selected.channel) $($selected.platform) is already $installedVersion"
        exit 0
    }
    if ($installedVersion) { "installed: $installedVersion" }
}

$installerPath = Save-EdgeInstaller $selected $DownloadDir
"downloaded: $installerPath"

if ($Action -eq "Install") {
    Install-EdgeInstaller $installerPath $selected.artifact
}
