# Hush — Epics & Tasks

## Epic 1: Project Scaffold

**Goal:** App launches with no Dock icon; menu bar area is reachable.

- [x] Create Xcode project (macOS App, AppKit lifecycle, Swift, macOS 13 target)
- [x] Configure `Info.plist`: `LSUIElement = YES`, `NSAccessibilityUsageDescription`, `NSUserNotificationsUsageDescription`
- [x] Configure `Hush.entitlements`: `app-sandbox`, `apple-events`
- [x] `HushApp.swift` — `@main`, `NSApplicationDelegateAdaptor`
- [x] `AppDelegate.swift` — `setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`

**Done when:** app launches, no Dock icon, no crash.

---

## Epic 2: Models

**Goal:** Data models compile cleanly.

- [x] `Models/QuitRecord.swift` — `{ id: UUID, appName: String, bundleIdentifier: String, quitDate: Date }`, Identifiable + Codable
- [x] `Models/AppEntry.swift` — `{ bundleIdentifier: String, displayName: String }`, Identifiable

**Done when:** both files compile with no warnings.

---

## Epic 3: Core — WhitelistManager

**Goal:** Persisted allow-list with observable state.

- [x] `Core/WhitelistManager.swift`
- [x] `@Published var whitelistedBundleIDs: Set<String>`
- [x] `UserDefaults` persistence (key: `"closerWhitelist"`)
- [x] `add(bundleID:)`, `remove(bundleID:)`, `isWhitelisted(bundleID:)`
- [x] `runningRegularApps() -> [NSRunningApplication]` helper
- [x] Hardcoded default entries merged at init

**Done when:** unit tests pass for add/remove/persist/isWhitelisted.

---

## Epic 4: Core — WindowChecker

**Goal:** Reliable window count via Accessibility API.

- [x] `Core/WindowChecker.swift`
- [x] `windowCount(for pid: pid_t) -> Int`
- [x] Returns `0` on `.noValue`, `-1` on error (safe fail → do not quit)
- [x] `isAccessibilityGranted() -> Bool` helper

**Done when:** returns correct count for open/closed VSCode windows.

---

## Epic 5: Core — AppQuitter

**Goal:** Terminate app + fire notification + return QuitRecord.

- [x] `Core/AppQuitter.swift`
- [x] `quit(app:, onQuit: (QuitRecord) -> Void)`
- [x] `app.terminate()`
- [x] `UNMutableNotificationContent` with app name
- [x] Constructs and returns `QuitRecord`

**Done when:** calling it on a test app quits the app and a notification fires.

---

## Epic 6: Core — AppMonitor

**Goal:** Watches workspace events and auto-quits windowless apps.

- [x] `Core/AppMonitor.swift`
- [x] Subscribes to `didDeactivate`, `didHide`, `didTerminate` workspace notifications
- [x] `scheduleCheck(for app:)` with per-pid `DispatchWorkItem` debouncing
- [x] `performCheck(app:)` with all 6 gates
- [x] `WindowCheckerProtocol` for dependency injection / testability
- [x] Publishes `recentlyQuit: [QuitRecord]`

**Done when:** VSCode auto-quits ~1s after closing its last window.

---

## Epic 7: Menu Bar UI

**Goal:** Fully functional popover with all controls.

- [x] `UI/MenuBarController.swift` — `NSStatusItem` + `NSPopover` + click-outside monitor
- [x] `UI/PopoverView.swift` — root layout, enable/disable toggle, footer
- [x] `UI/RecentlyQuitView.swift` — scrollable list + "Keep" button
- [x] `UI/WhitelistEditorView.swift` — list + [+] sheet with running apps

**Done when:** popover opens/closes, toggle persists, whitelist add/remove works.

---

## Epic 8: Launch at Login + Polish

**Goal:** App survives logout/login; Accessibility banner guides user.

- [x] `SMAppService.mainApp.register()` / `.unregister()` tied to toggle
- [x] Accessibility permission banner in `PopoverView` when `AXIsProcessTrusted() == false`
- [x] Deep link button: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
- [x] Notification permission request at first launch

**Done when:** "Launch at Login" toggle persists; app starts after logout/login.

---

## Verification Checklist

| # | Test | Expected |
|---|---|---|
| 1 | Launch app | No Dock icon, menu bar icon visible |
| 2 | Close all VSCode windows | VSCode quits in ~1s, notification fires |
| 3 | Close Docker Desktop window | Docker NOT quit (`.accessory` policy) |
| 4 | Whitelist VSCode, close windows | VSCode NOT quit |
| 5 | Toggle Hush off, close VSCode | VSCode NOT quit |
| 6 | Revoke Accessibility, close VSCode | VSCode NOT quit (safe fail) |
| 7 | Enable Launch at Login, logout | Hush starts automatically |
