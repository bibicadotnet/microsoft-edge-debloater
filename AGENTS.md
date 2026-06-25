# AGENTS.md

## Project overview

This repo builds a cross-platform Microsoft Edge installer and debloater.

PowerShell is the desktop runtime. Scripts must support Windows PowerShell 5.1 or newer and include `#requires -Version 5.1`.

## Setup commands

- Check latest Edge versions: `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action Versions`
- Select an installer: `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action SelectInstaller`
- Export policies: `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action ExportPolicy -PolicyFormat json`
- Audit policies: `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action AnalyzePolicy`

## Testing instructions

- Run the default self-test after script or policy changes: `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action SelfTest`
- For policy preset changes, also run:
  - `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action AnalyzePolicy -PolicyPreset Minimal`
  - `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action AnalyzePolicy -PolicyPreset Default`
  - `pwsh -NoProfile ./Invoke-EdgeDebloat.ps1 -Action AnalyzePolicy -PolicyPreset Strict`

## Code style

- Prefer one universal top-level command that detects platform and dispatches into `src/`.
- Keep platform-specific code under `src/Windows`, `src/MacOS`, or `src/Linux` when a split is needed.
- Use Microsoft-style PowerShell naming.
- Keep shared helpers in `src/Common.ps1`.
- Avoid compatibility wrappers and speculative abstractions.
- Prefer DRY/SRP and self-descriptive names over explanatory comments.

## Policy instructions

- Keep Windows browser `.reg` policy sources separate from EdgeUpdate policy sources.
- Generate macOS/Linux browser policies from the browser policy source.
- Validate cross-platform exports against the bundled Microsoft Edge policy manifest.
- Preserve Microsoft sign-in, sync, passwords, autofill, share, and cross-device features in the `Default` preset.
- Use `Minimal` for light debloat and `Strict` for account/sync/password/autofill lockdowns.

## Security considerations

- Do not disable WebView2 update/install policy by default; Windows apps may depend on WebView2.
- Do not apply or persist `edge://flags` by default. Treat flags as research-only unless explicitly requested.
- Do not remove user data, profiles, bookmarks, history, or extension backups unless explicitly requested.

## Discovery tips

- Prefer codebase-memory-mcp graph tools for code discovery when available.
- Fall back to `rg`, `find`, and direct reads for non-code files, configs, scripts not indexed by the graph, or stale MCP results.
