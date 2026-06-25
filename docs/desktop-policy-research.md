# Desktop Edge policy research

Last checked: 2026-06-25.

The desktop debloater should use PowerShell as the shared runtime for Windows, macOS, and Linux. Scripts must stay compatible with Windows PowerShell 5.1 or newer; use `powershell.exe` on stock Windows systems and `pwsh` on macOS/Linux. The policy backend is different per OS:

| OS | Policy surface | Repo handling |
| --- | --- | --- |
| Windows | Microsoft Edge supports Group Policy and direct registry policy under `HKLM\SOFTWARE\Policies\Microsoft\Edge`. The current repo applies `policies/windows/edge-browser-debloat.reg`. | Keep `.reg` as the source policy list for Windows. PowerShell can import it with `reg.exe import` when running on Windows. |
| macOS | Microsoft documents Edge policy deployment through a property list with the case-sensitive preference domain `com.microsoft.Edge`; all Edge channels read that domain on current builds. | Generate `com.microsoft.Edge.plist` from the same policy list. Deploy through MDM/Jamf for managed fleets, or apply locally for testing with macOS tools. |
| Linux | Chromium-family browsers read mandatory/recommended policy JSON files from admin-owned policy directories. Edge follows the same policy model, but the distro/package path must be verified on the target host. | Generate JSON from the same policy list. Install it as an admin-owned managed policy file on Linux, then verify in `edge://policy`. |

Microsoft splits browser behavior policies from updater policies:

- Browser policies configure Edge itself and are listed in the Microsoft Edge browser policy reference.
- Update policies configure Microsoft Edge Update, use the Windows registry path `HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate`, and include update/install controls such as `UpdateDefault`, `InstallDefault`, per-channel update policy, and WebView2 Runtime install/update policy.

Keep these as separate policy sets. Do not put EdgeUpdate values in the macOS/Linux browser policy export.

`policies/windows/edge-update-disable.reg` sets `UpdateDefault=0` and the four per-channel `Update{GUID}=0` values documented by Microsoft. It intentionally does not set WebView2 Runtime install/update values, because Windows apps may depend on WebView2.

## Policy export

Use the PowerShell 5.1+ compatible exporter to derive macOS/Linux policy files from `policies/windows/edge-browser-debloat.reg`:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action AnalyzePolicy
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat json -OutputPath ./generated/edge/managed-policy.json
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat plist -OutputPath ./generated/edge/com.microsoft.Edge.plist
pwsh ./Invoke-EdgeDebloat.ps1 -Action ApplyPolicy
```

The exporter reads `policies/templates/Stable/149/mac/policy_manifest.json`, extracted from Microsoft's Stable 149 policy template download, to coerce known boolean DWORD policies into real JSON/plist booleans. The macOS/Linux export is manifest-strict: policy names missing from the Stable 149 manifest are reported by `AnalyzePolicy` and skipped in generated JSON/plist output. Use `-DwordMode Boolean01` only for ad hoc checks without a manifest, because some Edge policies use `0` and `1` as enum values rather than booleans.

Policy presets:

| Preset | Count | Handling |
| --- | ---: | --- |
| `Minimal` | 28 | First-run, new-tab, recommendations, tracking, and light bloat controls. |
| `Default` | 128 | Main debloat preset. Leaves Microsoft sign-in, sync, passwords, autofill, share, and cross-device features user-controlled. |
| `Strict` | 148 | Includes sync-adjacent Microsoft account, password, autofill, share, and cross-device lockdowns. |

Windows apply also uses the preset: PowerShell generates a temporary filtered `.reg` file before importing it. macOS/Linux generate preset-filtered plist/JSON.

The original Microsoft template CABs are stored under `policies/templates/Stable/149/`. The checked-in manifest is the small runtime input; unpacked ZIP contents are generated material and belong under `generated/`.

Regenerate the manifest with `python3 policies/templates/Extract-PolicyManifest.py`; the script uses `bsdtar` for CAB extraction and Python's standard `zipfile` module for `MicrosoftEdgePolicyTemplates.zip`.

Current `AnalyzePolicy -PolicyPreset Default` result for the registry debloat list against the Stable 149 macOS manifest:

| Status | Count | Handling |
| --- | ---: | --- |
| Known | 97 | Exported to macOS plist and Linux JSON. |
| Deprecated | 7 | Reported, skipped in macOS/Linux export. |
| Unknown | 24 | Reported, skipped in macOS/Linux export. |

List-policy item names are validated through their parent policy name, so entries such as `ExtensionInstallForcelist\1` and `URLBlocklist\1` are not treated as unknown policies.

The default browser policy set leaves Microsoft sign-in, browser sync, passwords, autofill, share, and cross-device upload features user-controlled. Those are sync-adjacent features, not safe debloat defaults.

## Verification

After applying a policy file, open `edge://policy` in Microsoft Edge and confirm:

- the expected policy names appear
- the policy status is OK
- no value-type or source errors are listed

This matters because Windows registry files do not carry enough type information to distinguish every boolean policy from every integer enum policy.

You can export the local `edge://policy` status dump and inspect it with:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action InspectPolicy -PolicyDumpPath ~/Downloads/policies.json
```

The local macOS dump from 2026-06-25 reported Microsoft Edge `149.0.4022.80 (Official build) (arm64)` on macOS `26.5.1` with `0` applied policies. That dump is useful as a before/after verification artifact, but it is not a policy type schema.

## Sources

- Microsoft Learn: [Configure Microsoft Edge policy settings on Windows devices](https://learn.microsoft.com/en-us/deployedge/configure-microsoft-edge)
- Microsoft Learn: [Configure Microsoft Edge policy settings for macOS using a property list](https://learn.microsoft.com/en-us/deployedge/configure-microsoft-edge-on-mac)
- Microsoft Learn: [Microsoft Edge browser policy reference](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies)
- Microsoft Learn: [Microsoft Edge update policy reference](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-update-policies)
- Chromium Docs: [Enterprise policies](https://chromium.googlesource.com/chromium/src/+/main/docs/enterprise/policies.md)
- Chromium Docs: [Linux Quick Start](https://www.chromium.org/administrators/linux-quick-start/)
