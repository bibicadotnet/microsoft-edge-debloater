# Microsoft Edge platform support

Last checked: 2026-06-25.

This project started as a Windows Edge installer/debloater. Cross-platform support should mean "use the strongest supported control surface on each OS", not "pretend every OS can run Windows registry policy".

## Current latest versions

Microsoft's Edge update API reported these current channel versions on 2026-06-25:

| Channel | Windows | macOS | Linux | iOS | Android |
| --- | --- | --- | --- | --- | --- |
| Stable | 149.0.4022.80 | 149.0.4022.80 | 149.0.4022.80 | 149.0.4022.80 | 149.0.4022.80 |
| Beta | 150.0.4078.28 | 150.0.4078.28 | 150.0.4078.28 | 150.0.4078.29 | 150.0.4078.29 |
| Dev | 151.0.4105.0 | 151.0.4105.0 | 151.0.4105.0 | 146.0.3817.0 | 145.0.3800.8 |
| Canary | 151.0.4115.0 | 151.0.4115.0 | 151.0.4115.0 | not listed | 151.0.4111.0 |

For automation, scripts should read `https://edgeupdates.microsoft.com/api/products` instead of hard-coding these values. Run `pwsh ./Invoke-EdgeDebloat.ps1 -Action Versions` from the repository root to print the current matrix. Run `pwsh ./Invoke-EdgeDebloat.ps1 -Action SelectInstaller -Channel Stable` to print the latest desktop installer URL for the current OS.

## Platform matrix

| Platform | Supported by Microsoft | Maximum useful capability in this repo |
| --- | --- | --- |
| Windows | Windows 10 SAC 1709+, Windows 10 LTSC listed by Microsoft, Windows 11, and supported Windows Server releases. Edge 128+ requires CPUs with SSE3. | Install Stable/Beta/Dev/Canary, apply Edge browser and EdgeUpdate policies through registry files or PowerShell, remove desktop Edge while keeping WebView2 when requested. |
| macOS | Microsoft Edge 139+ requires macOS 12 Monterey or later. Apple Silicon has native Stable support from Edge 88. | Install/update through Microsoft's `.pkg` artifacts, apply Edge policies with `com.microsoft.Edge.plist`, and verify in `edge://policy`. Do not use Windows registry policy. |
| Linux | Microsoft says Edge is supported on Linux. The update API publishes x64 `.deb` and `.rpm` artifacts for desktop channels. | Install/update through Microsoft packages, apply Edge policies with admin-owned managed JSON, and verify in `edge://policy`. No EdgeUpdate service removal equivalent should be assumed. |
| iOS | Microsoft Edge for iPhone and iPad requires iOS 18.0 or later and tracks the two most recent major iOS versions. | Export managed app configuration plist payloads for Intune/UEM. Apple does not allow repo scripts to install or modify app internals on normal iOS devices. |
| Android | Android 10.0+ on ARM-based phones and tablets. | Export Android Enterprise managed configuration JSON payloads for Intune/UEM. Normal Android devices should not be treated like writable desktop installs. |

## Desktop installer helper

`Invoke-EdgeDebloat.ps1` selects the current desktop artifact from Microsoft's Edge update API:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action SelectInstaller -Channel Stable
pwsh ./Invoke-EdgeDebloat.ps1 -Action Download -Channel Stable
pwsh ./Invoke-EdgeDebloat.ps1 -Action InstallPackage -Channel Stable
```

The helper supports Windows `.msi`, macOS `.pkg`, Linux `.deb`, and Linux `.rpm` artifacts. Downloads are checked against the SHA256 hash from Microsoft's API when a hash is listed. `--install` runs the native installer command and may prompt for administrator or `sudo` access.

Mobile platforms are intentionally not handled by `--install`:

- iOS: install from the [Apple App Store](https://apps.apple.com/us/app/microsoft-edge/id1288723196) or deploy through an MDM system.
- Android: install from [Google Play](https://play.google.com/store/apps/details?id=com.microsoft.emmx) or deploy through Android Enterprise / managed Google Play.

## Desktop policy helper

PowerShell 5.1+ is the shared runtime for desktop policy work. `Invoke-EdgeDebloat.ps1` parses the Windows browser policy list in `policies/windows/edge-browser-debloat.reg` and exports macOS/Linux policy files. Use `powershell.exe` on stock Windows systems and `pwsh` on macOS/Linux:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat json -OutputPath ./generated/edge/managed-policy.json
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat plist -OutputPath ./generated/edge/com.microsoft.Edge.plist
pwsh ./Invoke-EdgeDebloat.ps1 -Action ApplyPolicy
```

See [desktop-policy-research.md](desktop-policy-research.md) for the OS-specific policy surfaces, source links, and type-handling notes.

## Mobile policy helper

iOS and Android policies are applied through MDM/UEM, not from a local desktop shell. The repo can generate import payloads:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -Platform iOS -PolicyFormat plist -OutputPath ./generated/edge/mobile-ios.plist
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -Platform Android -PolicyFormat json -OutputPath ./generated/edge/mobile-android.json
```

Import the output as an Edge app configuration policy for managed devices in Intune or another UEM.

## Release cadence

Microsoft says Stable moves to a two-week major release cycle starting with Edge 152. Extended Stable remains an 8-week option for managed enterprise environments.

## Local macOS check

`/Applications/Microsoft Edge.app` is installed locally. Its bundle identifier is `com.microsoft.edgemac`, and `CFBundleShortVersionString` reports `149.0.4022.80`, matching the Stable version from Microsoft's Edge update API on 2026-06-25.

## Sources

- Microsoft Learn: [Microsoft Edge supported operating systems](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-supported-operating-systems)
- Microsoft Learn: [Microsoft Edge release schedule](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-release-schedule)
- Microsoft Learn: [Microsoft Edge mobile policies](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-mobile-policies)
- Microsoft Learn: [Manage Microsoft Edge on iOS and Android with Intune](https://learn.microsoft.com/en-us/intune/app-management/configuration/configure-edge-ios-android)
- Microsoft: [Download Microsoft Edge](https://www.microsoft.com/en-us/edge/download)
- Apple App Store: [Microsoft Edge](https://apps.apple.com/us/app/microsoft-edge/id1288723196)
- Google Play: [Microsoft Edge](https://play.google.com/store/apps/details?id=com.microsoft.emmx)
- Microsoft Edge update API: <https://edgeupdates.microsoft.com/api/products>
