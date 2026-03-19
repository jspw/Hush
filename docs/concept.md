# Hush — Product Concept

## Problem

macOS does not automatically quit applications when their last window is closed. The result is a persistent "zombie" state: the app consumes memory, CPU, and occupies a slot in Cmd+Tab — yet does nothing useful.

Common offenders: VSCode, Slack, Figma, Chrome, Simulator — they all linger after their windows are gone.

## Key Insight

Not all windowless apps are zombies. macOS has a formal concept of **background-only apps**: apps that set `activationPolicy == .accessory` (e.g. Docker Desktop, Dropbox, 1Password mini). These apps intentionally have no windows and must be left alone.

Apps with `activationPolicy == .regular` that have zero windows, however, are genuine zombies — they registered as "foreground" apps but shed all their UI.

## Solution

**Hush** is a silent macOS menu bar utility that:

1. Watches for app deactivation events via `NSWorkspace`
2. Checks whether the deactivated app is a `.regular`-policy app with zero windows
3. If so, quietly calls `app.terminate()` within ~1 second
4. Posts a brief system notification so the user knows what happened

Hush itself has no Dock icon (`LSUIElement = YES`). It is invisible except for a small menu bar icon.

## User Controls

| Control | Purpose |
|---|---|
| Enable / Disable toggle | Master switch — disables all auto-quitting |
| Whitelist | Apps Hush will never auto-quit (user-managed) |
| Recently Quit list | Shows what was quit; "Keep" button adds app to whitelist |
| Launch at Login | Registers Hush as a login item via `SMAppService` |

## Default Whitelist

Some `.regular`-policy apps are expected to run without windows (e.g. Finder, System Settings, Xcode during build). Hush ships with a hardcoded default whitelist:

- `com.apple.finder`
- `com.apple.systempreferences`
- `com.apple.dt.Xcode`
