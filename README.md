# Hush

> Silently quits macOS apps when their last window is closed.

macOS keeps apps running after you close their last window — they linger in Cmd+Tab, waste memory, and do nothing. Hush fixes this quietly.

## How it works

Hush lives in your menu bar. When you close an app's last window, Hush detects it within ~1 second and calls `terminate()` on it automatically. Apps that are intentionally backgrounded (Docker, Dropbox — anything with an `.accessory` activation policy) are never touched.

## Features

- Auto-quits windowless apps within ~1 second
- Never quits background-only apps (Docker, Dropbox, etc.)
- Whitelist — protect apps you want to keep running
- Recently Quit list with "Keep" button to undo
- Launch at Login
- 0% CPU, ~130MB RAM at idle

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (for window counting)

## Installation

### Download

Grab the latest `.dmg` from [Releases](https://github.com/jspw/Hush/releases).

### Build from source

```bash
git clone https://github.com/jspw/Hush.git
cd Hush
xcodebuild -project Hush.xcodeproj -scheme Hush -destination 'platform=macOS' build
```

Or open `Hush.xcodeproj` in Xcode and hit Cmd+R.

### First launch

Grant **Accessibility** permission when prompted, or go to:
**System Settings → Privacy & Security → Accessibility → add Hush**

## Why not App Store?

The App Store requires sandboxing, which blocks the Accessibility API Hush depends on to count windows. Direct download only.

## Contributing

PRs welcome. Open an issue first for large changes.

## License

MIT
