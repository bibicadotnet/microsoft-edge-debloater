# Edge flags research

Last checked: 2026-06-25.

Baseline: Microsoft Edge Stable `149.0.4022.80` on macOS, using the copied `edge://flags` list from the local browser. This file is intentionally research-only. `edge://flags` entries are experimental, profile-local, version-sensitive, and not the right default deployment surface for this debloater. Use enterprise policies when a policy exists.

## Recommendation matrix

| Area | Examples from the local dump | Recommendation |
| --- | --- | --- |
| Policy control | `#edge-optin-experimentation`, `#edge-cloud-policy-v2`, `#edge-cloud-policy-v2-tasks` | Prefer `ExperimentationAndConfigurationServiceControl` and `FeatureFlagOverridesControl` policies instead of changing flags. |
| AI/Copilot | `#edge-compose`, `#edge-copilot-mode`, `#edge-omnibox-consumer-copilot-chat`, `#edge-llm-*`, `#edge-studio-ntp*` | Keep flags at default and disable supported surfaces through policies. User reports and current coverage show AI entry points change quickly. |
| Debug/developer | `#enable-benchmarking`, `#memlog`, `#enable-network-logging-to-file`, `#enable-gpu-service-logging`, `#webtransport-developer-mode`, `#unsafely-treat-insecure-origin-as-secure` | Do not enable in a debloat preset. These are diagnostic or unsafe developer features. |
| Graphics/media | `#ignore-gpu-blocklist`, `#enable-gpu-rasterization`, `#enable-zero-copy`, `#disable-accelerated-video-decode`, `#disable-accelerated-video-encode`, `#skia-graphite` | Leave defaults. Hardware behavior is machine-specific and bad defaults are easier to recover from than forced flags. |
| Web platform experiments | `#enable-experimental-web-platform-features`, `#enable-javascript-harmony`, `#enable-experimental-webassembly-features`, `#web-machine-learning-neural-network` | Leave defaults. These are compatibility and security-sensitive. |
| Privacy/security hardening | `#strict-origin-isolation`, `#origin-keyed-processes-by-default`, `#bind-cookies-to-port`, `#bind-cookies-to-scheme`, `#local-network-access-check` | Track as research candidates only. Some improve isolation but can change site compatibility. |
| Cast/PWA/workspaces/PDF | `#cast-*`, `#enable-desktop-pwas-*`, `#edge-workspaces-*`, `#edge-new-pdf-viewer`, `#edge-pdf-*` | Leave defaults unless a matching enterprise policy exists and the feature is part of the debloat goal. |
| Unavailable on macOS | `#smooth-scrolling`, `#enable-vulkan`, `#edge-dlp-protected-downloads`, `#edge-find-aura`, `#edge-omnibox-aura`, `#edge-allow-mam-on-mdm`, `#force-high-performance-gpu`, `#enable-perfetto-system-tracing` | Do not include in macOS guidance. Re-check on Windows/Linux before documenting as desktop-wide. |

## Policy equivalents to prefer

| Goal | Policy |
| --- | --- |
| Stop users or command lines from overriding feature flags | `FeatureFlagOverridesControl` |
| Restrict experimentation/configuration payloads | `ExperimentationAndConfigurationServiceControl` |
| Disable Compose writing features | `ComposeInlineEnabled` |
| Disable sidebar entry points | `HubsSidebarEnabled` and related sidebar policies |
| Disable supported Copilot surfaces | Use current Edge 149 Copilot policies from the Microsoft policy reference, not `edge://flags`. |
| Disable WebUSB/WebHID prompts | `DefaultWebUsbGuardSetting`, `DefaultWebHidGuardSetting`, and allow/block URL policies |
| Reduce WebRTC local IP exposure | `WebRtcLocalIpsAllowedUrls` and `WebRtcLocalhostIpHandling` |

## Community signal

Recent user discussion around Edge is mostly about AI/Copilot prominence, sidebar churn, background resource use, and privacy. That supports a policy-first debloat stance for AI, recommendations, shopping, sidebar, telemetry, and new-tab content. It does not justify forcing experimental flags by default.

## Sources

- Microsoft Learn: [Microsoft Edge browser policy reference](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies)
- Microsoft Learn: [Microsoft Edge update policy reference](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-update-policies)
- Microsoft Learn: [FeatureFlagOverridesControl](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/featureflagoverridescontrol)
- Microsoft Learn: [ExperimentationAndConfigurationServiceControl](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/experimentationandconfigurationservicecontrol)
- Chromium source: [about_flags.cc](https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/about_flags.cc)
- Windows Central: [Microsoft Edge retiring Drop for Copilot space](https://www.windowscentral.com/software-apps/microsoft-is-retiring-edge-drop-to-make-room-for-copilot)
- The Verge: [Microsoft Edge Copilot access across tabs](https://www.theverge.com/tech/930188/microsoft-edge-copilot-ai-tabs)
- TechRadar: [Copilot visibility/sidebar user concerns](https://www.techradar.com/computing/windows/microsoft-promised-it-would-scale-back-on-ai-visibility-but-copilot-is-now-back-to-its-original-and-invasive-sidebar-design)
- Local user input: copied Microsoft Edge `149.0.4022.80` macOS `edge://flags` list.
