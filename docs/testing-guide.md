# Hush — Testing Guide

## Prerequisites

1. **Xcode 15+** installed (for macOS 13+ target)
2. **Accessibility permission** — Hush needs this to count app windows

---

## Running the App

### Option A: Xcode (recommended for development)

```bash
open Hush.xcodeproj
```

1. In Xcode, select the **Hush** scheme and **My Mac** as destination
2. Press **Cmd+R** to build and run
3. The app will appear as a small **⊠** icon in the menu bar (no Dock icon)

### Option B: Command line build + run

```bash
# Build
xcodebuild -project Hush.xcodeproj -scheme Hush -configuration Debug -destination 'platform=macOS' build

# Find and run the built app
open ~/Library/Developer/Xcode/DerivedData/Hush-*/Build/Products/Debug/Hush.app
```

---

## First Launch Setup

On first launch, macOS will prompt for two permissions:

### 1. Accessibility Permission (required)

Hush uses the Accessibility API to count app windows. Without it, Hush cannot determine if an app has zero windows and will safely do nothing.

**To grant:**
1. Open **System Settings → Privacy & Security → Accessibility**
2. Click the **+** button
3. Navigate to `Hush.app` and add it
4. Toggle it **on**

> If running from Xcode, you may need to add **Xcode** itself to the Accessibility list instead of Hush.app.

**To verify:** The Hush popover will show an orange "Accessibility access required" banner if permission is missing.

### 2. Notification Permission (optional)

Hush sends a notification when it quits an app. If denied, quitting still works — you just won't see the notification.

macOS should prompt automatically on first launch. If not:
- **System Settings → Notifications → Hush** → enable **Allow Notifications**

---

## Manual Test Checklist

### Test 1: Menu bar icon appears, no Dock icon
1. Launch Hush
2. **Verify:** ⊠ icon appears in the menu bar
3. **Verify:** No Hush icon in the Dock
4. **Verify:** Clicking the icon opens the popover

### Test 2: Auto-quit a windowless app
1. Open **TextEdit** (or any standard app)
2. Close all its windows (Cmd+W)
3. Click on another app (to deactivate TextEdit)
4. **Verify:** TextEdit quits within ~1 second
5. **Verify:** A notification appears: "TextEdit was quit (no open windows)."
6. **Verify:** TextEdit appears in the "Recently Quit" list in the popover

### Test 3: Background apps are NOT quit
1. Make sure **Docker Desktop** or **Dropbox** is running (any `.accessory` policy app)
2. Switch away from it
3. **Verify:** It is NOT quit — these are intentional background apps

### Test 4: Whitelist prevents quitting
1. Open the Hush popover
2. Click **[+]** in the Whitelist section
3. Add **TextEdit** (or your test app)
4. Open TextEdit, close all windows, switch away
5. **Verify:** TextEdit is NOT quit

### Test 5: "Keep" button adds to whitelist
1. Let Hush quit an app (e.g., TextEdit)
2. Open the popover, find TextEdit in "Recently Quit"
3. Click **Keep**
4. **Verify:** TextEdit moves to the Whitelist section
5. **Verify:** TextEdit is no longer quit when windowless

### Test 6: Enable/Disable toggle
1. Open the popover, toggle Hush **off**
2. Open TextEdit, close all windows, switch away
3. **Verify:** TextEdit is NOT quit
4. Toggle Hush back **on**
5. Repeat — TextEdit should be quit again

### Test 7: Accessibility revoked = safe failure
1. Go to **System Settings → Privacy & Security → Accessibility**
2. Toggle Hush **off**
3. Open TextEdit, close all windows, switch away
4. **Verify:** TextEdit is NOT quit (Hush fails safely)
5. **Verify:** The popover shows the orange "Accessibility access required" banner

### Test 8: Launch at Login
1. Open the popover
2. Toggle **Launch at Login** on
3. Log out and log back in (or restart)
4. **Verify:** Hush starts automatically (⊠ icon in menu bar)

---

## Good Test Apps

| App | Policy | Expected Behavior |
|---|---|---|
| TextEdit | `.regular` | Quit when windowless |
| Preview | `.regular` | Quit when windowless |
| Calculator | `.regular` | Quit when windowless |
| Finder | `.regular` (whitelisted) | NOT quit (hardcoded whitelist) |
| System Settings | `.regular` (whitelisted) | NOT quit (hardcoded whitelist) |
| Docker Desktop | `.accessory` | NOT quit (background app) |
| Dropbox | `.accessory` | NOT quit (background app) |

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| App not quitting anything | Accessibility not granted | Grant in System Settings → Accessibility |
| App not quitting anything | Hush toggled off | Check the toggle in the popover |
| Notification not showing | Notification permission denied | Enable in System Settings → Notifications |
| "Keep" not working | — | Check that the app's bundle ID matches |
| Popover not opening | Status item not created | Restart Hush |
| Xcode build fails | Wrong developer directory | Run: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |

---

## Debugging Tips

- **Console.app** — Filter by process "Hush" to see system logs
- **Activity Monitor** — Check if Hush is running and its memory usage
- **Xcode debugger** — Set breakpoints in `AppMonitor.performCheck` to trace the 6-gate logic
- To check an app's activation policy from Terminal:
  ```swift
  // In a Swift playground or script:
  NSWorkspace.shared.runningApplications.forEach {
      print("\($0.localizedName ?? "?") — \($0.activationPolicy.rawValue)")
  }
  // 0 = .regular, 1 = .accessory, 2 = .prohibited
  ```
