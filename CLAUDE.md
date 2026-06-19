# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

**Hush** is a native macOS menu bar utility (Swift 5.9+, macOS 13+) that automatically quits applications when their last window is closed, while preserving background-only apps (Docker, Dropbox, etc.). No App Store — distributed as a notarized DMG or Homebrew cask due to sandbox incompatibility.

## Build & Run

There are **two build paths** that produce the same app from the same `Hush/` sources.

### Script build (no Xcode required — uses only Command Line Tools)

This is the release path, modeled on the sibling ScrollSense app. It builds via SwiftPM ([Package.swift](Package.swift)) and assembles a signed `.app`.

```bash
./setup-signing.sh   # once: creates a stable "Hush Self-Signed" cert
./build-app.sh       # swift build + assemble build/Hush.app (+ icon, Info.plist, codesign)
./install.sh         # copy to /Applications and launch
```

Why the stable cert: ad-hoc signatures change every rebuild, so macOS forgets the Accessibility grant on each update. Signing with the fixed `Hush Self-Signed` identity keeps the designated requirement stable — **grant Accessibility once and it persists across updates**. ([build-app.sh](build-app.sh) falls back to ad-hoc with a warning if the cert is missing.)

### Xcode build (requires full Xcode)

```bash
open Hush.xcodeproj
xcodebuild -project Hush.xcodeproj -scheme Hush -configuration Debug -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/Hush-*/Build/Products/Debug/Hush.app
```

### Icons & images

- **App icon:** [make-icon.sh](make-icon.sh) downscales `Hush/Assets.xcassets/AppIcon.appiconset/icon_1024.png` into `Resources/AppIcon.icns` (referenced via `CFBundleIconFile` in the script build). The Xcode build uses the asset catalog directly via `CFBundleIconName` in [Hush/Info.plist](Hush/Info.plist).
- **In-app images** (menu bar glyph, popover logo): embedded as base64 PNG bytes in [Hush/EmbeddedAssets.swift](Hush/EmbeddedAssets.swift) and decoded with `NSImage(data:)`. This avoids depending on the asset catalog (which needs `actool`/Xcode), so both build paths load them identically. The `MenuBarIcon`/`HushIcon` imagesets in the catalog are now unused.

**Testing:** No automated test suite. Manual testing uses the checklist in [docs/testing-guide.md](docs/testing-guide.md). Requires Accessibility permission granted in System Settings → Privacy & Security → Accessibility.

**Distribution:** See [docs/distribution-guide.md](docs/distribution-guide.md) for notarization and release workflow.

## Architecture

### Startup Flow

[HushApp.swift](Hush/HushApp.swift) (`@main`) → [AppDelegate.swift](Hush/AppDelegate.swift) (`applicationDidFinishLaunching`)

`AppDelegate` sets `NSApp.activationPolicy(.accessory)` (no Dock icon), prompts for Accessibility permission, then wires up components in dependency order:

```
WindowChecker → WhitelistManager → AppQuitter → AppMonitor → MenuBarController
```

### Core Logic

[AppMonitor.swift](Hush/Core/AppMonitor.swift) is the main event loop:
- Subscribes to `NSWorkspace` notifications (`didDeactivateApplication`, `didHideApplication`, `didTerminateApplication`)
- Debounces checks per-PID (0.8s delay) to avoid false positives
- Polls frontmost app every 2 seconds as fallback for window-close events that don't trigger deactivation

**6-gate validation before quitting:** enabled? → running? → `.regular` activation policy? → not whitelisted? → not self? → zero windows?

[WindowChecker.swift](Hush/Core/WindowChecker.swift) uses the Accessibility API (`AXUIElement`) to count windows. Returns `-1` on failure (treated as "has windows" — safe fallback).

[AppQuitter.swift](Hush/Core/AppQuitter.swift) calls `terminate()` and posts a `UNUserNotification`.

[WhitelistManager.swift](Hush/Core/WhitelistManager.swift) persists the user whitelist to `UserDefaults` key `"hushWhitelist"`. Hardcoded defaults: Finder, System Settings, Xcode.

### UI Layer

[MenuBarController.swift](Hush/UI/MenuBarController.swift) manages `NSStatusItem` + `NSPopover` (320×420pt). The popover embeds SwiftUI [PopoverView.swift](Hush/UI/PopoverView.swift), which composes: header, enable/disable banner, recently-quit list, whitelist editor, footer. Recently-quit records are in-memory only (`@Published recentlyQuit` array in `AppMonitor`).

### Permissions

- **Accessibility:** Required for window counting. Prompted at launch; gracefully skipped (returns `-1`) if denied.
- **Notifications:** Optional. Requested once at launch; quit still works if denied.

### Key Design Decisions

- `.regular` activation policy is the signal that an app should quit when windowless (vs `.accessory`/`.prohibited` for intentional background apps).
- No external dependencies — pure Swift + AppKit/SwiftUI/UserDefaults.
- Not sandboxed (required for Accessibility API and `terminate()` on other processes).
