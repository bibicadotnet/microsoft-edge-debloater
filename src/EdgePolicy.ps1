#requires -Version 5.1

param(
    [ValidateSet("Apply", "Export", "Analyze", "InspectDump", "SelfTest")]
    [string]$Action = "Export",

    [string]$InputPath = "policies/windows/edge-browser-debloat.reg",

    [string]$PolicyManifestPath = "policies/templates/Stable/149/mac/policy_manifest.json",

    [ValidateSet("Auto", "Windows", "MacOS", "Linux", "iOS", "Android")]
    [string]$Platform = "Auto",

    [ValidateSet("Standard", "High", "Extreme")]
    [string]$Preset = "High",

    [string]$PolicyDumpPath,

    [ValidateSet("json", "plist")]
    [string]$Format = "json",

    [string]$OutputPath,

    [ValidateSet("Integer", "Boolean01")]
    [string]$DwordMode = "Integer",

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CurrentPolicyPlatform {
    $platform = [System.Environment]::OSVersion.Platform.ToString()
    if ($platform -match "Win") { return "Windows" }
    if ($platform -eq "Unix") {
        if (Test-Path -LiteralPath "/System/Library/CoreServices/SystemVersion.plist") { return "MacOS" }
        return "Linux"
    }
    return $platform
}

function Convert-RegString {
    param([string]$Value)
    return $Value.Replace('\"', '"').Replace('\\', '\')
}

function Read-PolicyManifestTypes {
    param([string]$Path)

    $types = @{}
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $types }

    $manifest = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    foreach ($property in $manifest.properties.PSObject.Properties) {
        $configured = $property.Value.anyOf | Where-Object { $_.type -ne "null" } | Select-Object -First 1
        if ($configured) { $types[$property.Name] = [string]$configured.type }
    }
    return $types
}

function Get-DeprecatedPolicyNames {
    $names = @(
        "AllowGamesMenu",
        "CopilotCDPPageContext",
        "EdgeWalletEtreeEnabled",
        "PromotionalTabsEnabled",
        "RelatedWebsiteSetsEnabled",
        "ShowOfficeShortcutInFavoritesBar",
        "WalletDonationEnabled",
        "WebWidgetAllowed"
    )
    $set = @{}
    foreach ($name in $names) { $set[$name] = $true }
    return $set
}

function Get-PolicyPresetExclusions {
    param([string]$Name)

    $syncAdjacent = @(
        "AADWebSSOAllowed",
        "AADWebSiteSSOUsingThisProfileEnabled",
        "ApplicationGuardFavoritesSyncEnabled",
        "AutofillAddressEnabled",
        "AutofillCreditCardEnabled",
        "AutofillMembershipsEnabled",
        "ConfigureOnPremisesAccountAutoSignIn",
        "ConfigureShare",
        "EdgeAutofillMlEnabled",
        "MSAWebSiteSSOUsingThisProfileAllowed",
        "PasswordDismissCompromisedAlertEnabled",
        "PasswordGeneratorEnabled",
        "PasswordManagerEnabled",
        "PasswordMonitorAllowed",
        "PasswordProtectionWarningTrigger",
        "ProactiveAuthWorkflowEnabled",
        "RoamingProfileSupportEnabled",
        "SeamlessWebToBrowserSignInEnabled",
        "SharedLinksEnabled",
        "UploadFromPhoneEnabled"
    )
    if ($Name -eq "Extreme") { return @{} }

    $excluded = @{}
    foreach ($policy in $syncAdjacent) { $excluded[$policy] = $true }
    return $excluded
}

function Get-PolicyPresetIncludes {
    param([string]$Name)

    $included = @{}
    if ($Name -ne "Standard") { return $included }

    foreach ($policy in @(
        "AlternateErrorPagesEnabled",
        "AutoImportAtFirstRun",
        "BingAdsSuppression",
        "BlockThirdPartyCookies",
        "ConfigureDoNotTrack",
        "CopilotAddressBarSuggestionsEnabled",
        "CopilotNewTabPageEnabled",
        "DiagnosticData",
        "EdgeAssetDeliveryServiceEnabled",
        "EdgeCollectionsEnabled",
        "EdgeShoppingAssistantEnabled",
        "ExtensionManifestV2Availability",
        "HideFirstRunExperience",
        "HubsSidebarEnabled",
        "Microsoft365CopilotChatIconEnabled",
        "NewTabPageAppLauncherEnabled",
        "NewTabPageBingChatEnabled",
        "NewTabPageSearchBox",
        "PersonalizationReportingEnabled",
        "PinBrowserEssentialsToolbarButton",
        "ResolveNavigationErrorsUseWebService",
        "SearchInSidebarEnabled",
        "ShowMicrosoftRewards",
        "ShowRecommendationsEnabled",
        "TrackingPrevention",
        "URLBlocklist",
        "UrlDiagnosticDataEnabled",
        "UserFeedbackAllowed"
    )) { $included[$policy] = $true }
    return $included
}

function Convert-RegDword {
    param([string]$Name, [int]$Value, [string]$Mode, [hashtable]$PolicyTypes)

    if ($PolicyTypes.ContainsKey($Name) -and $PolicyTypes[$Name] -eq "boolean") {
        if ($Value -ne 0 -and $Value -ne 1) { throw "$Name is boolean in policy manifest but has DWORD value $Value" }
        return [bool]$Value
    }
    if ($Mode -eq "Boolean01" -and ($Value -eq 0 -or $Value -eq 1)) {
        return [bool]$Value
    }
    return $Value
}

function Read-EdgeRegPolicy {
    param([string]$Path, [string]$Mode, [hashtable]$PolicyTypes = @{}, [switch]$ManifestOnly, [hashtable]$ExcludePolicies = @{}, [hashtable]$IncludePolicies = @{})

    $policies = [ordered]@{}
    $lists = @{}
    $section = ""

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith(";") -or $trimmed -eq "Windows Registry Editor Version 5.00") {
            continue
        }

        if ($trimmed -match '^\[(.+)\]$') {
            $section = $Matches[1]
            continue
        }

        if ($section -notmatch '^HKEY_(CURRENT_USER|LOCAL_MACHINE)\\SOFTWARE\\Policies\\Microsoft\\Edge(\\(.+))?$') {
            continue
        }

        $subkey = $null
        if ($section -match '^HKEY_(CURRENT_USER|LOCAL_MACHINE)\\SOFTWARE\\Policies\\Microsoft\\Edge\\(.+)$') {
            $subkey = $Matches[2]
        }
        if ($trimmed -notmatch '^"([^"]+)"=(dword:([0-9a-fA-F]+)|"(.*)")$') {
            continue
        }

        $name = $Matches[1]
        $policyName = if ($subkey) { $subkey } else { $name }
        if ($ExcludePolicies.ContainsKey($policyName)) {
            continue
        }
        if ($IncludePolicies.Count -gt 0 -and -not $IncludePolicies.ContainsKey($policyName)) {
            continue
        }
        if ($ManifestOnly -and -not $PolicyTypes.ContainsKey($policyName)) {
            continue
        }

        $rawString = $Matches[4]
        $isDword = $Matches[2].StartsWith("dword:")
        $value = if ($isDword) {
            Convert-RegDword $policyName ([Convert]::ToInt32($Matches[3], 16)) $Mode $PolicyTypes
        } else {
            Convert-RegString $rawString
        }

        if ($subkey) {
            if (-not $lists.ContainsKey($subkey)) {
                $lists[$subkey] = @{}
            }
            $lists[$subkey][$name] = $value
        } else {
            $policies[$name] = $value
        }
    }

    foreach ($listName in ($lists.Keys | Sort-Object)) {
        $items = $lists[$listName].GetEnumerator() | Sort-Object {
            $n = 0
            if ([int]::TryParse($_.Key, [ref]$n)) { $n } else { [int]::MaxValue }
        }, Key | ForEach-Object { $_.Value }
        $policies[$listName] = @($items)
    }

    return $policies
}

function Escape-Xml {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape($Value)
}

function ConvertTo-PlistValue {
    param($Value, [int]$Indent = 1)

    $pad = "  " * $Indent
    if ($Value -is [bool]) {
        if ($Value) { return "$pad<true/>" }
        return "$pad<false/>"
    }
    if ($Value -is [int]) {
        return "$pad<integer>$Value</integer>"
    }
    if ($Value -is [array]) {
        $lines = @("$pad<array>")
        foreach ($item in $Value) {
            $lines += ConvertTo-PlistValue $item ($Indent + 1)
        }
        $lines += "$pad</array>"
        return ($lines -join [Environment]::NewLine)
    }
    return "$pad<string>$(Escape-Xml ([string]$Value))</string>"
}

function ConvertTo-Plist {
    param([hashtable]$Policies)

    $lines = @(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
        '<plist version="1.0">',
        '<dict>'
    )
    foreach ($key in $Policies.Keys) {
        $lines += "  <key>$(Escape-Xml $key)</key>"
        $lines += ConvertTo-PlistValue $Policies[$key] 1
    }
    $lines += @('</dict>', '</plist>')
    return ($lines -join [Environment]::NewLine)
}

function Get-MobileDisabledFeatures {
    param([string]$PlatformName, [string]$PresetName)

    if ($PresetName -eq "Standard") { return $null }

    $features = @("drop", "coupons", "weather")
    if ($PresetName -eq "Extreme") {
        $features += @("password", "inprivate", "autofill", "translator", "readaloud", "webinspector", "share", "sendtodevices")
        if ($PlatformName -eq "Android") { $features += "extensions" }
    }
    return ($features -join "|")
}

function Get-MobileEdgePolicies {
    param([string]$PlatformName, [string]$PresetName)

    $policies = [ordered]@{
        EdgeDisableShareUsageData = $true
        EdgeCopilotEnabled = $false
        HideFirstRunExperience = $true
        ExperimentationAndConfigurationServiceControl = 1
    }

    $disabledFeatures = Get-MobileDisabledFeatures $PlatformName $PresetName
    if ($disabledFeatures) {
        $policies.EdgeDisabledFeatures = $disabledFeatures
    }

    if ($PlatformName -eq "Android" -and $PresetName -ne "Standard") {
        $policies.EdgeNewTabPageLayout = "focused"
        $policies.EdgeNewTabPageLayoutUserSelectable = $false
    }

    if ($PresetName -eq "Extreme") {
        $policies.EdgeSyncDisabled = $true
        $policies.EdgeBlockSignInEnabled = $true
        $policies.EdgeImportPasswordsDisabled = $true
    }

    return $policies
}

function ConvertTo-RegString {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function ConvertTo-RegPolicy {
    param([hashtable]$Policies)

    $lines = @(
        "Windows Registry Editor Version 5.00",
        "",
        "[-HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Edge]",
        "[-HKEY_CURRENT_USER\Software\Policies\Microsoft\Edge]",
        "",
        "[HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge]"
    )
    foreach ($key in $Policies.Keys) {
        $value = $Policies[$key]
        if ($value -is [array]) { continue }
        if ($value -is [bool]) {
            $dword = if ($value) { "00000001" } else { "00000000" }
            $lines += "`"$key`"=dword:$dword"
        } elseif ($value -is [int]) {
            $lines += "`"$key`"=dword:$($value.ToString("x8"))"
        } else {
            $lines += "`"$key`"=`"$(ConvertTo-RegString ([string]$value))`""
        }
    }
    foreach ($key in $Policies.Keys) {
        $value = $Policies[$key]
        if ($value -isnot [array]) { continue }
        $lines += ""
        $lines += "[HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge\$key]"
        for ($index = 0; $index -lt $value.Count; $index++) {
            $lines += "`"$($index + 1)`"=`"$(ConvertTo-RegString ([string]$value[$index]))`""
        }
    }
    return ($lines -join [Environment]::NewLine)
}

function Get-EdgePolicies {
    param(
        [string]$Path,
        [string]$Mode,
        [string]$ManifestPath,
        [string]$PresetName,
        [switch]$ManifestOnly
    )

    $policyTypes = Read-PolicyManifestTypes $ManifestPath
    $policies = Read-EdgeRegPolicy $Path $Mode $policyTypes -ManifestOnly:$ManifestOnly -ExcludePolicies (Get-PolicyPresetExclusions $PresetName) -IncludePolicies (Get-PolicyPresetIncludes $PresetName)
    if ($ManifestOnly) {
        $deprecated = Get-DeprecatedPolicyNames
        foreach ($name in @($policies.Keys)) {
            if ($deprecated.ContainsKey($name)) {
                $policies.Remove($name)
            }
        }
    }
    return $policies
}

function Export-EdgePolicy {
    param(
        [string]$Path,
        [string]$OutFormat,
        [string]$OutPath,
        [string]$Mode,
        [string]$ManifestPath,
        [string]$PresetName,
        [string]$PlatformName
    )

    $policies = if ($PlatformName -eq "iOS" -or $PlatformName -eq "Android") {
        Get-MobileEdgePolicies $PlatformName $PresetName
    } else {
        Get-EdgePolicies $Path $Mode $ManifestPath $PresetName -ManifestOnly
    }
    $content = if ($OutFormat -eq "json") {
        $policies | ConvertTo-Json -Depth 8
    } else {
        ConvertTo-Plist $policies
    }

    if ($OutPath) {
        $parent = Split-Path -Parent $OutPath
        if ($parent) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        Set-Content -LiteralPath $OutPath -Value $content -Encoding utf8
    } else {
        $content
    }
}

function Analyze-EdgePolicy {
    param([string]$Path, [string]$ManifestPath, [string]$PresetName, [switch]$AsJson)

    $policyTypes = Read-PolicyManifestTypes $ManifestPath
    $deprecated = Get-DeprecatedPolicyNames
    $excluded = Get-PolicyPresetExclusions $PresetName
    $included = Get-PolicyPresetIncludes $PresetName
    $policies = Read-EdgeRegPolicy $Path "Integer" @{} -ExcludePolicies $excluded -IncludePolicies $included
    $items = @()
    foreach ($name in $policies.Keys) {
        $status = if ($deprecated.ContainsKey($name)) {
            "deprecated"
        } elseif ($policyTypes.ContainsKey($name)) {
            "known"
        } else {
            "unknown"
        }
        $items += [pscustomobject]@{
            name = $name
            status = $status
            type = if ($policyTypes.ContainsKey($name)) { $policyTypes[$name] } else { $null }
            value = $policies[$name]
        }
    }
    $summary = [ordered]@{
        source = $Path
        manifest = $ManifestPath
        preset = $PresetName
        excluded = $excluded.Count
        included = $included.Count
        total = $items.Count
        known = @($items | Where-Object { $_.status -eq "known" }).Count
        deprecated = @($items | Where-Object { $_.status -eq "deprecated" }).Count
        unknown = @($items | Where-Object { $_.status -eq "unknown" }).Count
        policies = $items
    }

    if ($AsJson) {
        $summary | ConvertTo-Json -Depth 8
        return
    }

    "source: $($summary.source)"
    "manifest: $($summary.manifest)"
    "preset: $($summary.preset)"
    "excluded: $($summary.excluded)"
    "included: $($summary.included)"
    "total: $($summary.total)"
    "known: $($summary.known)"
    "deprecated: $($summary.deprecated)"
    "unknown: $($summary.unknown)"
    foreach ($policy in ($items | Sort-Object status, name)) {
        $type = if ($policy.type) { $policy.type } else { "-" }
        "$($policy.status): $($policy.name) [$type]"
    }
}

function Copy-WithSudo {
    param([string]$Source, [string]$TargetDirectory, [string]$TargetName)

    Invoke-NativeCommand "sudo" @("mkdir", "-p", $TargetDirectory)
    Invoke-NativeCommand "sudo" @("cp", $Source, (Join-Path $TargetDirectory $TargetName))
    Invoke-NativeCommand "sudo" @("chmod", "644", (Join-Path $TargetDirectory $TargetName))
}

function Invoke-NativeCommand {
    param([string]$FilePath, [string[]]$Arguments)

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

function Apply-EdgePolicy {
    param([string]$Path, [string]$PlatformName, [string]$PresetName)

    if ($PlatformName -eq "Auto") { $PlatformName = Get-CurrentPolicyPlatform }

    if ($PlatformName -eq "Windows") {
        $outPath = Join-Path ([System.IO.Path]::GetTempPath()) "microsoft-edge-debloater.reg"
        ConvertTo-RegPolicy (Get-EdgePolicies $Path "Integer" $PolicyManifestPath $PresetName) | Set-Content -LiteralPath $outPath -Encoding unicode
        Invoke-NativeCommand "reg.exe" @("import", $outPath)
        "policy applied: $outPath"
        return
    }

    if ($PlatformName -eq "MacOS") {
        $outPath = Join-Path ([System.IO.Path]::GetTempPath()) "com.microsoft.Edge.plist"
        Export-EdgePolicy $Path "plist" $outPath "Integer" $PolicyManifestPath $PresetName $PlatformName
        Copy-WithSudo $outPath "/Library/Managed Preferences" "com.microsoft.Edge.plist"
        "policy applied: /Library/Managed Preferences/com.microsoft.Edge.plist"
        return
    }

    if ($PlatformName -eq "Linux") {
        $outPath = Join-Path ([System.IO.Path]::GetTempPath()) "microsoft-edge-debloater.json"
        Export-EdgePolicy $Path "json" $outPath "Integer" $PolicyManifestPath $PresetName $PlatformName
        Copy-WithSudo $outPath "/etc/opt/edge/policies/managed" "microsoft-edge-debloater.json"
        "policy applied: /etc/opt/edge/policies/managed/microsoft-edge-debloater.json"
        return
    }

    if ($PlatformName -eq "iOS" -or $PlatformName -eq "Android") {
        throw "Mobile policy apply is not local. Export a mobile payload and import it with Intune or another UEM."
    }

    throw "Policy apply is only implemented for Windows, macOS, and Linux."
}

function Get-DumpPolicies {
    param($Node)

    $items = @()
    if (-not $Node) { return $items }

    foreach ($property in $Node.PSObject.Properties) {
        $value = $property.Value
        $names = @($value.PSObject.Properties | ForEach-Object { $_.Name })
        if ($value -and $names -contains "policies") {
            foreach ($policy in $value.policies.PSObject.Properties) {
                $fields = $policy.Value.PSObject.Properties
                $items += [pscustomobject]@{
                    group = $property.Name
                    name = $policy.Name
                    value = if ($fields["value"]) { $fields["value"].Value } else { $null }
                    source = if ($fields["source"]) { $fields["source"].Value } else { $null }
                    level = if ($fields["level"]) { $fields["level"].Value } else { $null }
                    status = if ($fields["status"]) { $fields["status"].Value } else { $null }
                }
            }
        }
    }
    return $items
}

function Inspect-PolicyDump {
    param([string]$Path, [switch]$AsJson)

    if (-not $Path) { throw "InspectDump requires -PolicyDumpPath" }
    $dump = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $policies = @(Get-DumpPolicies $dump.policyValues)
    $summary = [ordered]@{
        application = [string]$dump.chromeMetadata.application
        version = [string]$dump.chromeMetadata.version
        os = [string]$dump.chromeMetadata.OS
        policyCount = $policies.Count
        policies = $policies
    }

    if ($AsJson) {
        $summary | ConvertTo-Json -Depth 8
        return
    }

    "$($summary.application) $($summary.version)"
    $summary.os
    "policies: $($summary.policyCount)"
    foreach ($policy in $policies) {
        $state = if ($policy.status) { $policy.status } elseif ($policy.source -or $policy.level) { "$($policy.source)/$($policy.level)" } else { "unknown" }
        "$($policy.group): $($policy.name) [$state]"
    }
}

function Invoke-SelfTest {
    $sample = @'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge]
"HideFirstRunExperience"=dword:00000001
"NewTabPageSearchBox"="redirect"
"SleepingTabsTimeout"=dword:00000384

[HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Edge\URLBlocklist]
"1"="ntp.msn.com"
"2"="example.com"
'@
    $path = Join-Path ([System.IO.Path]::GetTempPath()) "edge-policy-test.reg"
    Set-Content -LiteralPath $path -Value $sample -Encoding utf8
    $policies = Read-EdgeRegPolicy $path "Integer" @{ HideFirstRunExperience = "boolean" }
    if ($policies.HideFirstRunExperience -ne $true) { throw "Manifest boolean parse failed" }
    if ($policies.NewTabPageSearchBox -ne "redirect") { throw "String parse failed" }
    if ($policies.SleepingTabsTimeout -ne 900) { throw "Hex DWORD parse failed" }
    if ($policies.URLBlocklist.Count -ne 2) { throw "List policy parse failed" }
    $knownOnly = Read-EdgeRegPolicy $path "Integer" @{ HideFirstRunExperience = "boolean"; URLBlocklist = "array" } -ManifestOnly
    if ($knownOnly.Contains("NewTabPageSearchBox")) { throw "Manifest-only filter failed" }
    if ($knownOnly.URLBlocklist.Count -ne 2) { throw "Manifest-only list parse failed" }
    $excludedPolicies = Read-EdgeRegPolicy $path "Integer" @{} -ExcludePolicies @{ NewTabPageSearchBox = $true }
    if ($excludedPolicies.Contains("NewTabPageSearchBox")) { throw "Preset exclusion failed" }
    if ((Get-PolicyPresetExclusions "High").ContainsKey("PasswordManagerEnabled") -ne $true) { throw "High preset failed" }
    if ((Get-PolicyPresetExclusions "Extreme").Count -ne 0) { throw "Extreme preset failed" }
    if ((Get-PolicyPresetIncludes "Standard").ContainsKey("HideFirstRunExperience") -ne $true) { throw "Standard preset failed" }
    $boolPolicies = Read-EdgeRegPolicy $path "Boolean01"
    if ($boolPolicies.HideFirstRunExperience -ne $true) { throw "Boolean01 mode failed" }
    $mobileStandard = Get-MobileEdgePolicies "iOS" "Standard"
    if ($mobileStandard.Contains("EdgeSyncDisabled")) { throw "Mobile standard should not disable sync" }
    if ($mobileStandard.EdgeCopilotEnabled -ne $false) { throw "Mobile Copilot preset failed" }
    $mobileHigh = Get-MobileEdgePolicies "Android" "High"
    if ($mobileHigh.EdgeDisabledFeatures -notmatch "drop") { throw "Mobile high features failed" }
    if ($mobileHigh.EdgeNewTabPageLayout -ne "focused") { throw "Android NTP preset failed" }
    $mobileExtreme = Get-MobileEdgePolicies "Android" "Extreme"
    if ($mobileExtreme.EdgeSyncDisabled -ne $true) { throw "Mobile extreme sync failed" }
    if ($mobileExtreme.EdgeDisabledFeatures -notmatch "extensions") { throw "Android extreme feature failed" }
    $mobileExtremeIos = Get-MobileEdgePolicies "iOS" "Extreme"
    if ($mobileExtremeIos.EdgeDisabledFeatures -match "extensions") { throw "iOS extreme feature filter failed" }

    $dump = @'
{
  "chromeMetadata": {
    "OS": "macOS Version 26.5.1",
    "application": "Microsoft Edge",
    "version": "149.0.4022.80 (Official build) (arm64)"
  },
  "policyValues": {
    "chrome": {
      "name": "Microsoft Edge Policies",
      "policies": {
        "HideFirstRunExperience": {
          "value": true,
          "source": "Platform machine",
          "status": "OK"
        }
      }
    }
  }
}
'@
    $dumpPath = Join-Path ([System.IO.Path]::GetTempPath()) "edge-policy-dump-test.json"
    Set-Content -LiteralPath $dumpPath -Value $dump -Encoding utf8
    $inspected = Get-Content -LiteralPath $dumpPath -Raw | ConvertFrom-Json
    if (@(Get-DumpPolicies $inspected.policyValues).Count -ne 1) { throw "Policy dump parse failed" }
}

if ($Action -eq "SelfTest") {
    Invoke-SelfTest
    exit 0
}

if ($Action -eq "InspectDump") {
    Inspect-PolicyDump -Path $PolicyDumpPath -AsJson:$Json
    exit 0
}

if ($Action -eq "Apply") {
    Apply-EdgePolicy $InputPath $Platform $Preset
    exit 0
}

if ($Action -eq "Analyze") {
    Analyze-EdgePolicy $InputPath $PolicyManifestPath $Preset -AsJson:$Json
    exit 0
}

Export-EdgePolicy $InputPath $Format $OutputPath $DwordMode $PolicyManifestPath $Preset $Platform
