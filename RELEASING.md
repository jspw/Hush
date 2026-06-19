# Releasing Hush

Maintainer runbook for shipping Hush. Hush has one release surface: the
`Hush-x.y.z.dmg` menu-bar app, published through GitHub Releases.

## One-Time Setup

```bash
./setup-signing.sh    # creates the stable "Hush Self-Signed" identity
gh auth login         # for publishing releases
```

Use the same signing identity for every release. The Accessibility permission is
tied to the app's code signature; changing the identity forces users to grant
permission again.

Hush is currently **self-signed, not Apple-notarized**. Public DMG users must
clear quarantine after install:

```bash
xattr -dr com.apple.quarantine /Applications/Hush.app
```

(Full notarization requires an Apple Developer account + a "Developer ID
Application" certificate. Once you have one, sign with it in `build-app.sh` and
add an `xcrun notarytool` step — until then the quarantine note above applies.)

## Version Sources

| Place | How it is set |
|-------|---------------|
| `VERSION` file (source of truth) | `./bump-version.sh` |
| `Hush.xcodeproj` `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `./bump-version.sh` (kept in sync) |
| App bundle `Info.plist` version | stamped at build time by `build-app.sh` from `VERSION` |

`MARKETING_VERSION` is the user-facing version (e.g. `1.6.0`); `BUILD_VERSION` is
a monotonic build counter that `bump-version.sh` auto-increments.

## Standard Release Flow

Replace `1.6.0` with the version being shipped.

1. Land the feature/fix commits.

2. Bump the version (sets marketing version, auto-increments build):

   ```bash
   ./bump-version.sh 1.6.0
   git diff
   git commit -am "Release v1.6.0 (build N)"
   ```

3. Publish the DMG + GitHub release:

   ```bash
   ./release.sh 1.6.0     # or just ./release.sh — defaults to the VERSION file
   ```

   This builds and signs the app, packages `build/Hush-1.6.0.dmg`, tags
   `v1.6.0`, and creates (or updates) the GitHub release.

## Pre-Release Smoke Test

```bash
./build-dmg.sh 1.6.0
open build/Hush-1.6.0.dmg
```

Install to Applications, clear quarantine if needed, then verify:

- menu-bar icon (the shush glyph) appears,
- Accessibility prompt opens and, once granted, windowless `.regular` apps quit,
- whitelisted apps (Finder, Docker, etc.) are left running,
- the popover header logo and recently-quit list render,
- after a rebuild + reinstall, the Accessibility grant **persists** (stable signature).

## Build Without Publishing

```bash
./build-app.sh           # build the .app only
./build-dmg.sh 1.6.0     # build the .app + package a DMG, no GitHub release
```

## Post-Release Verification

```bash
gh release view v1.6.0
curl -I https://github.com/jspw/Hush/releases/download/v1.6.0/Hush-1.6.0.dmg
```

## Failure Recovery

- **`release.sh` reran after a partial publish:** it reuses an existing `v1.6.0`
  tag/release and re-uploads the DMG with `--clobber`, so it's safe to rerun.
- **Users lose Accessibility after updating:** the signing identity changed.
  Have them remove the old Hush entry from System Settings → Privacy & Security →
  Accessibility, relaunch, and grant again. Going forward, always release with
  the same `Hush Self-Signed` identity.
