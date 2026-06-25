# Microsoft Edge Installer & Debloater

![Cy3C8dNa](https://img.bibica.net/Cy3C8dNa.png)

> **Note:** This guide helps you install, optimize, and completely disable updates for Microsoft Edge, while preserving essential functions like sync, extensions, and security settings.

Cross-platform support notes live in [docs/platform-support.md](docs/platform-support.md), including current Microsoft-supported OS requirements and what this repo can safely automate on Windows, macOS, Linux, iOS, and Android.

To check the latest Edge versions across desktop and mobile channels:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action Versions
```

To print the latest desktop installer URL for your current OS:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action SelectInstaller -Channel Stable
```

Use `-Action Download` to save the installer, or `-Action Install` to run the native Windows/macOS/Linux installer and apply desktop policies.

To export the Windows policy list for macOS or Linux:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat plist -OutputPath ./generated/edge/com.microsoft.Edge.plist
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat json -OutputPath ./generated/edge/managed-policy.json
```

To apply the desktop policy without reinstalling Edge:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action ApplyPolicy
```

Policy presets:

| Preset | Intent |
| --- | --- |
| `Default` | Debloat Edge while keeping Microsoft sign-in, sync, passwords, autofill, share, and cross-device features user-controlled. |
| `Minimal` | Apply only first-run, new-tab, recommendations, tracking, and light bloat policies. |
| `Strict` | Also disables sync-adjacent Microsoft account, password, autofill, share, and cross-device features. |

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action ApplyPolicy -PolicyPreset Minimal
pwsh ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyPreset Strict -PolicyFormat json
```

To audit the registry policy list against the bundled Edge 149 manifest:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action AnalyzePolicy -PolicyPreset Default
```

Optional browser-extension backups live in `config/extensions/` for manual import into Edge desktop profiles.

* Automatically and silently installs the latest version of Microsoft Edge (**Stable**, **Beta**, **Dev**, or **Canary**)
* Disables Microsoft Edge browser updates through EdgeUpdate policy while leaving WebView2 policy unset
* Applies browser policies from `policies/windows/edge-browser-debloat.reg` while retaining essential functionality:

  * Data Sync
  * Microsoft sign-in
  * Password and autofill sync
  * Auto Page Translate
  * Favorites Bar
  * Manifest V2 Extension Support
  * DNS over HTTPS (DoH)
  * Google Search
  * Automatic HTTPS
  * Performance: sleeping tabs discard inactive tabs after **15 minutes** to save RAM

---

## Edge Channels

Use Stable for normal installs. Beta, Dev, and Canary are preview channels and can change faster or break more often. Microsoft says Stable moves to a two-week major release cycle starting with Edge 152; use `pwsh ./Invoke-EdgeDebloat.ps1 -Action Versions` for current versions.

---

## Install Microsoft Edge Stable (Recommended)

The Stable channel is the normal Microsoft Edge release for daily use.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action Install -Channel Stable
```

## Install Microsoft Edge Beta

The Beta channel is a preview of upcoming Microsoft Edge releases with fewer surprises than Dev or Canary.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action Install -Channel Beta
```

## Install Microsoft Edge Dev

The Dev channel is an early-access Microsoft Edge build for testing upcoming browser changes.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action Install -Channel Dev
```

## Install Microsoft Edge Canary

The Canary channel is the most **cutting-edge** and **frequently updated** version of Microsoft Edge, receiving new features and changes **daily**.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action Install -Channel Canary
```

---

## Remove All Microsoft Edge Versions
This script removes all installed versions of Microsoft Edge (**Stable**, **Beta**, **Dev**, and **Canary**) from your system, but keeps your **User Data** folder and **Microsoft Edge WebView2 Runtime**, so that **bookmarks**, **history**, **settings**, and apps depending on WebView2 continue to work.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
pwsh ./Invoke-EdgeDebloat.ps1 -Action Remove -Platform Windows
```

---

## Only Debloater

If you only want to apply the tweaks without installing or disabling updates, you can:

1. **Download** the `microsoft-edge-debloater` tool [from here](https://github.com/bibicadotnet/microsoft-edge-debloater/archive/refs/heads/main.zip)
2. **Extract** the downloaded archive.
3. Run `policies/windows/edge-browser-debloat.reg` to apply the registry settings.
4. **Restart Microsoft Edge** by entering `edge://restart` in the address bar.

---

## Customize Further

If you want to enable/disable more features based on your personal preferences:

* Open `policies/windows/edge-browser-debloat.reg` in a text editor.
* **Comment out** lines you don’t want to apply by adding a semicolon `;` at the beginning of the line, or delete them.
* To apply changes:

  * Run `policies/windows/edge-browser-debloat.reg` again to apply the new configuration.

---

## Useful Edge URLs

| Purpose | URL |
| --- | --- |
| View applied policies | `edge://policy/` |
| Check Edge version info | `edge://version/` |

---

## Source Credits

This debloater configuration is based on and modified from the following open-source projects:

* [Bakinazik/microsoft-edge-debloater](https://github.com/bakinazik/edgedebloater)
* [Marlock9/Edge-Debloat](https://github.com/marlock9/edge-debloat)

Thank you to these creators for their contributions and insights into optimizing Microsoft Edge.

---
