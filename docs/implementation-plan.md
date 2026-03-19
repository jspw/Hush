# Hush — Implementation Plan

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (popover) + AppKit (status item, delegate lifecycle)
- **Minimum target:** macOS 13 Ventura
- **No Dock icon:** `LSUIElement = YES` in Info.plist
- **Distribution:** local / notarized direct download (no App Store sandbox needed initially)

---

## Project Structure

```
Hush/
├── HushApp.swift              # @main SwiftUI App, NSApplicationDelegateAdaptor
├── AppDelegate.swift            # setActivationPolicy(.accessory), wires up AppMonitor
├── Core/
│   ├── AppMonitor.swift         # NSWorkspace observer + debounced check dispatcher
│   ├── WindowChecker.swift      # AXUIElement window counting
│   ├── AppQuitter.swift         # terminate() + UNUserNotificationCenter
│   └── WhitelistManager.swift   # UserDefaults-backed allow-list + running apps helper
├── UI/
│   ├── MenuBarController.swift  # NSStatusItem + NSPopover lifecycle
│   ├── PopoverView.swift        # Root SwiftUI popover layout
│   ├── RecentlyQuitView.swift   # "Keep" list
│   └── WhitelistEditorView.swift# Add/remove whitelist entries
└── Models/
    ├── QuitRecord.swift         # { id, appName, bundleID, quitDate }
    └── AppEntry.swift           # { bundleID, displayName }
```

---

## Info.plist Keys

| Key | Value | Purpose |
|---|---|---|
| `LSUIElement` | `YES` | Hides Dock icon |
| `NSAccessibilityUsageDescription` | `"Hush needs Accessibility access to count app windows."` | Privacy prompt |
| `NSUserNotificationsUsageDescription` | `"Hush sends a notification when it quits an app."` | Notification prompt |

---

## Entitlements (Hush.entitlements)

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.automation.apple-events</key><true/>
```

---

## Core Flow

```
App Launch
  └─ NSApp.setActivationPolicy(.accessory)
  └─ Request Accessibility permission (AXIsProcessTrusted)
  └─ Request Notification permission (UNUserNotificationCenter)
  └─ Subscribe to NSWorkspace notifications

NSWorkspace Events (on main thread)
  ├─ didDeactivateApplicationNotification  ← primary trigger
  ├─ didHideApplicationNotification        ← Cmd+H coverage
  └─ didTerminateApplicationNotification   ← cancel pending checks

On Trigger (scheduleCheck)
  └─ Cancel any pending DispatchWorkItem for this pid
  └─ Create new DispatchWorkItem, schedule after 0.8s
      └─ performCheck(app):
          1. isEnabled?            → skip if false
          2. app still running?    → skip if terminated
          3. activationPolicy == .regular?  → skip if .accessory/.prohibited
          4. not whitelisted?      → skip if in whitelist
          5. not self (Hush)?    → skip
          6. windowCount == 0?     → skip if ≥1 window (or API error → -1)
          7. All pass → AppQuitter.quit(app)
```

---

## WindowChecker

Uses the Accessibility API to count windows:

```swift
func windowCount(for pid: pid_t) -> Int {
    let axApp = AXUIElementCreateApplication(pid)
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value)
    switch result {
    case .success:
        return (value as? [AXUIElement])?.count ?? 0
    case .noValue:
        return 0
    default:
        return -1   // API error → treat as "has windows" (safe fail)
    }
}
```

Run on a background `DispatchQueue`; dispatch `terminate()` back to main.

---

## Menu Bar UI (320 pt wide popover)

```
┌─────────────────────────────────┐
│  ⊠ Hush                  [●]  │  ← NSToggle: isEnabled
├─────────────────────────────────┤
│  Recently Quit                  │
│  VSCode            2 min ago  Keep│
│  Figma             5 min ago  Keep│
├─────────────────────────────────┤
│  Whitelist                   [+]│
│  Docker Desktop           [−]   │
│  Finder (built-in)              │
├─────────────────────────────────┤
│  Launch at Login           [●]  │
│            Quit Hush          │
└─────────────────────────────────┘
```

- Clicking the status icon toggles the popover
- Clicking outside dismisses (global `NSEvent` monitor)
- "Keep" adds to whitelist + removes from recently quit list
- [+] opens a sheet listing currently running `.regular` apps

---

## Default Whitelist (hardcoded, not removable)

```swift
static let defaults: Set<String> = [
    "com.apple.finder",
    "com.apple.systempreferences",
    "com.apple.dt.Xcode",
]
```

---

## Permissions Flow

1. **Accessibility** — checked at launch and on each `performCheck`. If not granted:
   - Banner in popover: "Accessibility access required → Open Settings"
   - Deep link: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
   - WindowChecker returns `-1` → safe no-quit

2. **Notifications** — requested once at first launch via `UNUserNotificationCenter.requestAuthorization`; gracefully degraded if denied (quit still works, notification skipped)
