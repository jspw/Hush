# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About

**Hush** is a native macOS menu bar utility (Swift 5.9+, macOS 13+) that automatically quits applications when their last window is closed, while preserving background-only apps (Docker, Dropbox, etc.). No App Store — distributed as a notarized DMG or Homebrew cask due to sandbox incompatibility.

## Build & Run

```bash
# Open in Xcode
open Hush.xcodeproj

# Build from command line
xcodebuild -project Hush.xcodeproj -scheme Hush -configuration Debug -destination 'platform=macOS' build

# Run built app
open ~/Library/Developer/Xcode/DerivedData/Hush-*/Build/Products/Debug/Hush.app
```

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
