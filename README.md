# Microsoft Edge Debloater

> **Note:** This guide helps you remove unnecessary features from Microsoft Edge while preserving essential functions like sync, extensions, and security settings.

## Features Preserved

- Data Sync
- Auto Page Translate
- Favorites Bar
- Manifest V2 Extension Support
- DNS over HTTPS (DoH)
- Extensions Installed:
  - uBlock Origin
  - I Still Don't Care About Cookies
 
## Setup Microsoft Edge Debloater
```
irm https://go.bibica.net/edge | iex
```
## Remove Microsoft Edge
```
irm https://go.bibica.net/remove-edge | iex
```

## Only Debloater

1. **Download** the `microsoft-edge-debloater` tool [from here](https://github.com/bibicadotnet/microsoft-edge-debloater/archive/refs/heads/main.zip)
2. **Extract** the downloaded archive.
3. **Run** the `en.edge.reg` file to apply the registry settings.
4. **Restart Microsoft Edge** by entering this in the address bar:

   ```
   edge://restart
   ```

## Restore Default Settings

If you encounter issues or feel that Edge is overly restricted:

- **To restore default settings:**
  - Run the `restore-default.reg` file to remove all registry modifications.
  - Or go to `edge://settings/reset` and click **Restore settings to their default values**.

## Customize Further

If you want to enable/disable more features based on your personal preferences:

- Open the `en.edge.reg` file in a text editor.
- **Comment out** lines you don’t want to apply by adding a semicolon `;` at the beginning of the line, or delete them.
- To apply changes:
  1. Run `restore-default.reg` to remove previous settings.
  2. Run `en.edge.reg` again to apply the new configuration.

## Useful Edge URLs

| Purpose | URL |
|--------|-----|
| View applied policies | `edge://policy/` |
| Check Edge version info | `edge://version/` |

## Source Credits

This debloater configuration is based on and modified from the following open-source projects:

- [Bakinazik/microsoft-edge-debloater](https://github.com/bakinazik/edgedebloater)
- [Marlock9/Edge-Debloat](https://github.com/marlock9/edge-debloat)

Thank you to these creators for their contributions and insights into optimizing Microsoft Edge.

---
