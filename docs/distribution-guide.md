# Hush — Distribution & Open Source Guide

## Distribution Options

### Option 1: Direct Download (Simplest)

Users download `Hush.app` from your website or GitHub Releases.

**Steps:**

1. **Get an Apple Developer account** — $99/year at [developer.apple.com](https://developer.apple.com/programs/)
2. **Create a Developer ID certificate** in Xcode → Settings → Accounts → Manage Certificates → "Developer ID Application"
3. **Archive the app:**
   - Xcode → Product → Archive
   - In the Organizer, click "Distribute App" → "Developer ID" → "Upload" (for notarization)
4. **Notarize** — Apple scans the app for malware. Xcode handles this automatically during the "Distribute App" step. Without notarization, users see a scary "unidentified developer" warning.
5. **Export the notarized app** — Xcode gives you a `.app` or you can wrap it in a `.dmg`
6. **Create a DMG** (optional, polished):
   ```bash
   hdiutil create -volname "Hush" -srcfolder /path/to/Hush.app -ov -format UDZO Hush.dmg
   ```
7. **Upload to GitHub Releases** or your website

**What users do:** Download → drag to /Applications → open → grant Accessibility.

---

### Option 2: Homebrew Cask (Best for developers)

Most popular way to distribute open source Mac apps.

1. First, distribute via GitHub Releases (Option 1)
2. Submit a cask to [homebrew-cask](https://github.com/Homebrew/homebrew-cask):
   ```ruby
   # Casks/hush.rb
   cask "hush" do
     version "1.0.0"
     sha256 "abc123..."
     url "https://github.com/YOUR_USER/hush/releases/download/v#{version}/Hush.dmg"
     name "Hush"
     desc "Auto-quit macOS apps when their last window is closed"
     homepage "https://github.com/YOUR_USER/hush"
     app "Hush.app"
   end
   ```
3. Users install with: `brew install --cask hush`

---

### Option 3: Mac App Store

Not recommended for Hush because:
- App Store requires **App Sandbox** — which blocks the Accessibility API that Hush depends on
- Hush can't work in a sandbox (we already had to disable it)
- Review process is slow and may reject accessibility-based utilities

---

## Without an Apple Developer Account ($0)

You can still distribute, but users will see warnings:

1. Build in Xcode → Product → Archive → Export (without notarization)
2. Users must: right-click → Open → "Open Anyway" (or System Settings → Privacy → allow)
3. This is fine for open source / developer-audience apps

---

## Open Sourcing on GitHub

### 1. Prepare the repo

```bash
cd /Users/mhshifat/Documents/personal-work/products/mac-app-closer
git init
```

### 2. Add a .gitignore

Key things to exclude:
- `DerivedData/`
- `.DS_Store`
- `*.xcuserstate`
- `xcuserdata/`
- Build artifacts

### 3. Choose a license

| License | What it allows | Good for |
|---|---|---|
| **MIT** | Do anything, just keep the copyright notice | Maximum adoption, simplest |
| **GPL-3.0** | Must open-source derivative works | Ensuring forks stay open source |
| **Apache-2.0** | Like MIT but with patent protection | If you want patent safety |

**Recommendation:** MIT — it's the standard for open source Mac utilities.

### 4. Create a good README

Should include:
- What Hush does (one sentence)
- Screenshot/GIF of the popover
- Installation instructions (DMG download + Homebrew)
- How it works (brief technical explanation)
- How to build from source
- License

### 5. GitHub Releases workflow

For each version:
```bash
# Tag the release
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

Then in GitHub → Releases → "Create release" → attach the `.dmg` file.

### 6. Optional: GitHub Actions CI

Auto-build on every push/tag:
```yaml
# .github/workflows/build.yml
name: Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild -project Hush.xcodeproj -scheme Hush -destination 'platform=macOS' build
```

---

## Recommended Path

1. **Now:** Open source on GitHub with MIT license (free, builds community)
2. **Later:** Get Apple Developer account when you want to distribute to non-technical users (notarized DMG + Homebrew cask)

The open source route is great for a utility like Hush — developers are the target audience, they're comfortable with `brew install`, and community contributions improve the app.

---

## Checklist

- [ ] Add `.gitignore`
- [ ] Add `LICENSE` (MIT)
- [ ] Add `README.md` with screenshot
- [ ] `git init` and push to GitHub
- [ ] Create first GitHub Release with `.app` zip
- [ ] (Later) Apple Developer account → notarize → DMG
- [ ] (Later) Submit Homebrew cask
