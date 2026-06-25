#!/usr/bin/env pwsh
#requires -Version 5.1

param(
    [ValidateSet("Install", "Remove", "Versions", "SelectInstaller", "Download", "InstallPackage", "ApplyPolicy", "ExportPolicy", "AnalyzePolicy", "InspectPolicy", "SelfTest")]
    [string]$Action = "Install",

    [ValidateSet("Stable", "Beta", "Dev", "Canary", "stable", "beta", "dev", "canary")]
    [string]$Channel = "Stable",

    [ValidateSet("Auto", "Windows", "MacOS", "Linux", "iOS", "Android")]
    [string]$Platform = "Auto",

    [string]$Architecture = "Auto",

    [ValidateSet("auto", "pkg", "msi", "deb", "rpm")]
    [string]$Package = "auto",

    [ValidateSet("json", "plist")]
    [string]$PolicyFormat = "json",

    [ValidateSet("Standard", "High", "Extreme")]
    [string]$PolicyPreset = "High",

    [string]$OutputPath,

    [string]$PolicyDumpPath,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { (Get-Location).Path }
. (Join-Path $ProjectRoot "src/Common.ps1")

$Channel = Get-EdgeChannelName $Channel
$Platform = Get-PlatformName $Platform

function Invoke-DesktopAction {
    param([string]$DesktopAction)

    $parameters = @{
        Action = $DesktopAction
        Channel = $Channel
        Platform = $Platform
        Architecture = $Architecture
        Package = $Package
    }
    if ($Json) { $parameters.Json = $true }
    Invoke-SourceScript -ProjectRoot $ProjectRoot -RelativePath "src/EdgeDesktop.ps1" -Parameters $parameters
}

function Invoke-PolicyAction {
    param([string]$PolicyAction)

    $parameters = @{
        Action = $PolicyAction
        Platform = $Platform
        Preset = $PolicyPreset
    }
    if ($PolicyAction -eq "Export") {
        $parameters.Format = $PolicyFormat
        if ($OutputPath) { $parameters.OutputPath = $OutputPath }
    }
    if ($PolicyAction -eq "Analyze") {
        if ($Json) { $parameters.Json = $true }
    }
    if ($PolicyAction -eq "InspectDump") {
        $parameters.PolicyDumpPath = $PolicyDumpPath
        if ($Json) { $parameters.Json = $true }
    }
    Invoke-SourceScript -ProjectRoot $ProjectRoot -RelativePath "src/EdgePolicy.ps1" -Parameters $parameters
}

switch ($Action) {
    "Install" {
        if ($Platform -eq "Windows") {
            Invoke-SourceScript -ProjectRoot $ProjectRoot -RelativePath "src/Windows/InstallEdge.ps1" -Parameters @{ Channel = $Channel.ToLowerInvariant() }
        } else {
            Invoke-DesktopAction "Install"
            Invoke-PolicyAction "Apply"
        }
    }
    "Remove" {
        if ($Platform -ne "Windows") { throw "Remove is only implemented for Windows desktop Edge." }
        Invoke-SourceScript -ProjectRoot $ProjectRoot -RelativePath "src/Windows/RemoveEdge.ps1"
    }
    "Versions" { Invoke-DesktopAction "Versions" }
    "SelectInstaller" { Invoke-DesktopAction "SelectInstaller" }
    "Download" { Invoke-DesktopAction "Download" }
    "InstallPackage" { Invoke-DesktopAction "Install" }
    "ApplyPolicy" { Invoke-PolicyAction "Apply" }
    "ExportPolicy" { Invoke-PolicyAction "Export" }
    "AnalyzePolicy" { Invoke-PolicyAction "Analyze" }
    "InspectPolicy" { Invoke-PolicyAction "InspectDump" }
    "SelfTest" {
        Invoke-SourceScript -ProjectRoot $ProjectRoot -RelativePath "src/EdgeDesktop.ps1" -Parameters @{ Action = "SelfTest" }
        Invoke-SourceScript -ProjectRoot $ProjectRoot -RelativePath "src/EdgePolicy.ps1" -Parameters @{ Action = "SelfTest" }
    }
}
