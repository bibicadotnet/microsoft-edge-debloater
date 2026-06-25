#requires -Version 5.1

function Get-ProjectRoot {
    param([string]$InvocationRoot)

    if (-not [string]::IsNullOrWhiteSpace($InvocationRoot)) { return $InvocationRoot }
    return (Get-Location).Path
}

function Get-PlatformName {
    param([string]$Name)

    if ($Name -ne "Auto") { return $Name }

    $platform = [System.Environment]::OSVersion.Platform.ToString()
    if ($platform -match "Win") { return "Windows" }
    if ($platform -eq "Unix") {
        if (Test-Path -LiteralPath "/System/Library/CoreServices/SystemVersion.plist") { return "MacOS" }
        return "Linux"
    }
    return $platform
}

function Get-EdgeChannelName {
    param([string]$Name)
    return $Name.Substring(0, 1).ToUpperInvariant() + $Name.Substring(1).ToLowerInvariant()
}

function Invoke-SourceScript {
    param(
        [string]$ProjectRoot,
        [string]$RelativePath,
        [hashtable]$Parameters = @{}
    )

    $scriptPath = Join-Path $ProjectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Missing script: $scriptPath" }
    & $scriptPath @Parameters
}
