# Microsoft Edge Debloater (Disable and Optimize)

> **Note:** This guide helps you install, optimize, and completely disable updates for Microsoft Edge, while preserving essential functions like sync, extensions, and security settings.

### Steps will be executed sequentially as follows:
-   Automatically and silently install Microsoft Edge.
-   **Completely disable all Microsoft Edge updates (automatic and manual via the updater)**, including stopping background processes, deleting scheduled tasks, and renaming the updater executables (`MicrosoftEdgeUpdate.exe`) to prevent their operation.
-   Apply registry tweaks to remove unnecessary Microsoft Edge features, keeping only essential functionalities such as:
    -   Data Sync
    -   Auto Page Translate
    -   Favorites Bar
    -   Manifest V2 Extension Support
    -   DNS over HTTPS (DoH)

## Install and Completely Disable Microsoft Edge Updates
Run the command below in PowerShell with **Administrator privileges**:
```powershell
irm https://go.bibica.net/edge_disable_update | iex
```
This command will download and run the script to install, configure, and completely disable Edge updates.

## Remove Microsoft Edge
Run the command below in PowerShell with **Administrator privileges**:
```powershell
iex "&{$(irm https://cdn.jsdelivr.net/gh/he3als/EdgeRemover@main/get.ps1)} -UninstallEdge"
```

## Only Debloater

If you only want to apply the tweaks without installing or disabling updates, you can:
1.  **Download** the `microsoft-edge-debloater` tool [from here](https://github.com/bibicadotnet/microsoft-edge-debloater/archive/refs/heads/main.zip)
2.  **Extract** the downloaded archive.
3.  **Run** the `en.edge.reg` file to apply the registry settings.
4.  **Restart Microsoft Edge** by entering `edge://restart` in the address bar.

## Restore Default Settings

If you encounter issues or feel that Edge is overly restricted:

-   **To restore all debloater settings (including registry tweaks and re-enabling updates):**
    *   You will need to rename the `MicrosoftEdgeUpdate.exe.disabled` file back to `MicrosoftEdgeUpdate.exe` and delete any lock files created. Afterwards, you can run `restore-default.reg` to remove the registry modifications.
    *   Alternatively, the simplest way is to reinstall Microsoft Edge from Microsoft's official website.
-   **To restore only the settings that were changed by registry tweaks:**
    *   Run the `restore-default.reg` file to remove all registry modifications.
    *   Or go to `edge://settings/reset` and click **Restore settings to their default values**.

## Customize Further

If you want to enable/disable more features based on your personal preferences:

-   Open the `en.edge.reg` file (from the `microsoft-edge-debloater` package) in a text editor.
-   **Comment out** lines you don’t want to apply by adding a semicolon `;` at the beginning of the line, or delete them.
-   To apply changes:
    1.  Run `restore-default.reg` to remove previous settings.
    2.  Run `en.edge.reg` again to apply the new configuration.

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
