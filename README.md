# Microsoft Edge Debloater

![Cy3C8dNa](https://img.bibica.net/Cy3C8dNa.png)

> **Note:** This guide helps you install, optimize, and completely disable updates for Microsoft Edge, while preserving essential functions like sync, extensions, and security settings.

-   Automatically and silently installs the latest Stable version of Microsoft Edge.
-   Completely disables all Microsoft Edge updates
-   Applies registry tweaks to remove unnecessary features from Edge while retaining essential functionalities:
    - Data Sync
    - Auto Page Translate
    - Favorites Bar
    - Manifest V2 Extension Support
    - DNS over HTTPS (DoH)
    - Google Search
    - Force HTTPS
    - Performance: sleeping tabs discard inactive tabs after 15 minutes to save RAM

## Install
Run the command below in PowerShell with **Administrator privileges**:
```powershell
irm https://go.bibica.net/edge_disable_update | iex
```
This command will download and run the script to install, configure, and completely disable Edge updates.

## Only Debloater

If you only want to apply the tweaks without installing or disabling updates, you can:
1.  **Download** the `microsoft-edge-debloater` tool [from here](https://github.com/bibicadotnet/microsoft-edge-debloater/archive/refs/heads/main.zip)
2.  **Extract** the downloaded archive.
3.  **Run** the `vi.edge.reg` file to apply the registry settings.
4.  **Restart Microsoft Edge** by entering `edge://restart` in the address bar.

## Customize Further

If you want to enable/disable more features based on your personal preferences:

-   Open the `vi.edge.reg` file (from the `microsoft-edge-debloater` package) in a text editor.
-   **Comment out** lines you don’t want to apply by adding a semicolon `;` at the beginning of the line, or delete them.
-   To apply changes:
    - Run `vi.edge.reg` again to apply the new configuration.

## Useful Edge URLs

| Purpose               | URL                     |
|-----------------------|-------------------------|
| View applied policies | `edge://policy/`        |
| Check Edge version info | `edge://version/`       |

## Source Credits

This debloater configuration is based on and modified from the following open-source projects:

-   [Bakinazik/microsoft-edge-debloater](https://github.com/bakinazik/edgedebloater)
-   [Marlock9/Edge-Debloat](https://github.com/marlock9/edge-debloat)

Thank you to these creators for their contributions and insights into optimizing Microsoft Edge.
