# Microsoft Edge Installer & Debloater

![Cy3C8dNa](https://img.bibica.net/Cy3C8dNa.png)

> **Note:** This guide helps you install, optimize, and completely disable updates for Microsoft Edge, while preserving essential functions like sync, extensions, and security settings.

* Automatically and silently installs the latest version of Microsoft Edge (**Stable**, **Beta**, **Dev**, or **Canary**)
* Completely disables all Microsoft Edge updates and removes unnecessary files
* Applies registry tweaks to remove unnecessary features from Edge while retaining essential functionalities:

  * Data Sync
  * Auto Page Translate
  * Favorites Bar
  * Manifest V2 Extension Support
  * DNS over HTTPS (DoH)
  * Google Search
  * Automatic HTTPS
  * Performance: sleeping tabs discard inactive tabs after **15 minutes** to save RAM

---

## Edge Channel Overview

| Channel    | Update Frequency | Stability | Intended For                                            |
| ---------- | ---------------- | --------- | ------------------------------------------------------- |
| **Stable** | Every 4 weeks    | ★★★★☆     | General users, maximum reliability                      |
| **Beta**   | Every 4 weeks    | ★★★☆☆     | Users who want to try upcoming features with fewer bugs |
| **Dev**    | Weekly           | ★★☆☆☆     | Developers and testers who want early features          |
| **Canary** | Daily            | ★☆☆☆☆     | Enthusiasts who want the newest features immediately    |

---

## Install Microsoft Edge Stable (Recommended)

The Stable channel is the **official, fully-tested release** of Microsoft Edge, updated **every four weeks** for **maximum reliability**.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
irm https://go.bibica.net/edge | iex
```

## Install Microsoft Edge Beta

The Beta channel is a **more stable preview** of Microsoft Edge, updated **every four weeks**, offering upcoming features with fewer bugs.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
$env:EDGE_CHANNEL='beta'; irm https://go.bibica.net/edge | iex
```

## Install Microsoft Edge Dev

The Dev channel is an **early-access** version of Microsoft Edge, updated **weekly** with new features and improvements for testing.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
$env:EDGE_CHANNEL='dev'; irm https://go.bibica.net/edge | iex
```

## Install Microsoft Edge Canary

The Canary channel is the most **cutting-edge** and **frequently updated** version of Microsoft Edge, receiving new features and changes **daily**.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
$env:EDGE_CHANNEL='canary'; irm https://go.bibica.net/edge | iex
```

---

## Remove All Microsoft Edge Versions
This script removes all installed versions of Microsoft Edge (**Stable**, **Beta**, **Dev**, and **Canary**) from your system, but keeps your **User Data** folder and **Microsoft Edge WebView2 Runtime**, so that **bookmarks**, **history**, **settings**, and apps depending on WebView2 continue to work.

Run the command below in PowerShell with **Administrator privileges**:

```powershell
irm https://go.bibica.net/remove_edge | iex
```

---

## Only Debloater

If you only want to apply the tweaks without installing or disabling updates, you can:

1. **Download** the `microsoft-edge-debloater` tool [from here](https://github.com/bibicadotnet/microsoft-edge-debloater/archive/refs/heads/main.zip)
2. **Extract** the downloaded archive.
3. **Run** the `vi.edge.reg` file to apply the registry settings.
4. **Restart Microsoft Edge** by entering `edge://restart` in the address bar.

---

## Customize Further

If you want to enable/disable more features based on your personal preferences:

* Open the `vi.edge.reg` file (from the `microsoft-edge-debloater` package) in a text editor.
* **Comment out** lines you don’t want to apply by adding a semicolon `;` at the beginning of the line, or delete them.
* To apply changes:

  * Run `vi.edge.reg` again to apply the new configuration.

---

## Useful Edge URLs

| Purpose                 | URL               |
| ----------------------- | ----------------- |
| View applied policies   | `edge://policy/`  |
| Check Edge version info | `edge://version/` |

---

## Source Credits

This debloater configuration is based on and modified from the following open-source projects:

* [Bakinazik/microsoft-edge-debloater](https://github.com/bakinazik/edgedebloater)
* [Marlock9/Edge-Debloat](https://github.com/marlock9/edge-debloat)

Thank you to these creators for their contributions and insights into optimizing Microsoft Edge.

---
