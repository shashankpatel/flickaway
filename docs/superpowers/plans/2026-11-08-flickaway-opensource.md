# Flick Away Open Source Packaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the app to Flick Away everywhere that matters for open source, add MIT licensing and docs, and ship both `build.sh` and a compile-ready `FlickAway.xcodeproj`.

**Architecture:** Keep the existing SwiftPM executable + `build.sh` app-bundle wrapper. Rename package/target/sources/identity strings, then add a committed XcodeGen-generated macOS app project that points at the same sources and `Info.plist`. No behavior changes.

**Tech Stack:** Swift 5.9+, AppKit/Accessibility on macOS 13+, Swift Package Manager, bash `build.sh`, XcodeGen (`project.yml` → `FlickAway.xcodeproj`), MIT license.

## Global Constraints

- Product name: **Flick Away** (user-facing everywhere)
- Bundle identifier: **`com.shashankpatel.flickaway`**
- Executable / Swift target: **`FlickAway`**
- App bundle: **`Flick Away.app`**
- License: **MIT**, copyright **Shashank Patel**, year **2026**
- Platform: **macOS 13.0+**, no third-party runtime dependencies
- Do not change move/overlay/hotkey behavior — packaging and rename only
- This folder may not be a git repository; **skip commit steps** unless `git rev-parse --is-inside-work-tree` succeeds and the user has asked for commits
- Spec: `docs/superpowers/specs/2026-11-08-flickaway-opensource-design.md`

## File Structure

| Path | Responsibility |
|------|----------------|
| `LICENSE` | MIT text |
| `README.md` | User-facing product + build + usage |
| `CONTRIBUTING.md` | Contributor build/test notes |
| `.gitignore` | SwiftPM + Xcode ignores |
| `Info.plist` | Bundle identity for both build paths |
| `Package.swift` | SPM executable `FlickAway` |
| `build.sh` | Release build → `Flick Away.app` + codesign |
| `project.yml` | XcodeGen source of truth for the Xcode project |
| `FlickAway.xcodeproj/` | Committed generated project users open in Xcode |
| `Sources/FlickAway/*.swift` | App sources (moved from `Sources/PiPFlick/`) |

---

### Task 1: Rename Swift package and sources

**Files:**
- Modify: `Package.swift`
- Move: `Sources/PiPFlick/` → `Sources/FlickAway/`
- Modify: `Sources/FlickAway/main.swift` (user-facing strings + logger subsystem)
- Modify: any other Swift files under `Sources/FlickAway/` that contain `PiP Flick` or `local.pipflick.utility`

**Interfaces:**
- Consumes: existing executable sources
- Produces: SPM package/target named `FlickAway`; sources at `Sources/FlickAway/`

- [ ] **Step 1: Update Package.swift**

Replace contents with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlickAway",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "FlickAway")]
)
```

- [ ] **Step 2: Move the source directory**

```bash
mv "Sources/PiPFlick" "Sources/FlickAway"
```

Expected: `Sources/FlickAway/` contains the six Swift files; `Sources/PiPFlick` is gone.

- [ ] **Step 3: Rename user-facing product strings and subsystem**

In `Sources/FlickAway/main.swift`:

1. Change `Logger(subsystem: "local.pipflick.utility", category: "Movement")` to `Logger(subsystem: "com.shashankpatel.flickaway", category: "Movement")`.
2. Replace every user-visible `"PiP Flick"` string with `"Flick Away"` (accessibility description, accessibility label, tooltip, About panel application name, About menu title pattern).
3. Leave internal type names such as `PiPDiscovery`, `PiPWindow`, and `PiPError` unchanged.

Also grep the whole `Sources/FlickAway` tree for remaining `PiP Flick` / `local.pipflick` / `pipflick` branding and update only user-facing or identity strings.

```bash
rg -n "PiP Flick|local\.pipflick|pipflick|PiPFlick" Sources/FlickAway Package.swift
```

Expected: no remaining `PiP Flick` product strings; `PiPFlick` target name gone from `Package.swift`; internal `PiP*` type names may remain.

- [ ] **Step 4: Verify SPM still builds**

```bash
swift build -c release
```

Expected: build succeeds and produces an executable named `FlickAway` under `.build/.../release/`.

- [ ] **Step 5: Commit (only if git + user requested)**

```bash
git add Package.swift Sources
git commit -m "$(cat <<'EOF'
Rename package and sources to FlickAway.

EOF
)"
```

---

### Task 2: Update Info.plist and build.sh

**Files:**
- Modify: `Info.plist`
- Modify: `build.sh`

**Interfaces:**
- Consumes: SPM target/executable `FlickAway` from Task 1
- Produces: app bundle `.build/Flick Away.app` with bundle id `com.shashankpatel.flickaway`

- [ ] **Step 1: Update Info.plist identity keys**

Set these keys (keep `CFBundleShortVersionString` / `CFBundleVersion` as currently present unless already changed):

```xml
<key>CFBundleExecutable</key>
<string>FlickAway</string>
<key>CFBundleIdentifier</key>
<string>com.shashankpatel.flickaway</string>
<key>CFBundleName</key>
<string>Flick Away</string>
```

Leave `LSUIElement` true, `LSMinimumSystemVersion` `13.0`, and other existing keys intact.

- [ ] **Step 2: Rewrite build.sh for Flick Away**

Replace `build.sh` with:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

scratch="${FLICKAWAY_BUILD_DIR:-$PWD/.build}"
signer="${FLICKAWAY_SIGN_IDENTITY:--}"
swift build --scratch-path "$scratch" -c release
bin="$(swift build --scratch-path "$scratch" -c release --show-bin-path)"

app="$scratch/Flick Away.app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
cp "$bin/FlickAway" "$app/Contents/MacOS/FlickAway"
codesign --force --sign "$signer" "$app"
printf '\nBuilt %s\n' "$app"
```

Ensure the file remains executable (`chmod +x build.sh`).

- [ ] **Step 3: Run the script and verify the bundle**

```bash
./build.sh
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' ".build/Flick Away.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print CFBundleName' ".build/Flick Away.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' ".build/Flick Away.app/Contents/Info.plist"
test -x ".build/Flick Away.app/Contents/MacOS/FlickAway"
codesign -dv ".build/Flick Away.app" 2>&1 | head -20
```

Expected:

- Script prints `Built .../Flick Away.app`
- Identifier `com.shashankpatel.flickaway`
- Name `Flick Away`
- Executable `FlickAway`
- Binary exists and is executable
- codesign reports a signature (ad-hoc is fine)

- [ ] **Step 4: Commit (only if git + user requested)**

```bash
git add Info.plist build.sh
git commit -m "$(cat <<'EOF'
Point Info.plist and build.sh at Flick Away identity.

EOF
)"
```

---

### Task 3: Add Xcode project via XcodeGen

**Files:**
- Create: `project.yml`
- Create: `FlickAway.xcodeproj/` (generated; commit the generated project)
- Modify: `.gitignore` (do **not** ignore `FlickAway.xcodeproj/`)

**Interfaces:**
- Consumes: `Sources/FlickAway/*.swift`, root `Info.plist`, bundle id `com.shashankpatel.flickaway`
- Produces: openable `FlickAway.xcodeproj` with scheme `FlickAway`

- [ ] **Step 1: Write project.yml**

Create `project.yml`:

```yaml
name: FlickAway
options:
  bundleIdPrefix: com.shashankpatel
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
settings:
  base:
    PRODUCT_NAME: Flick Away
    PRODUCT_BUNDLE_IDENTIFIER: com.shashankpatel.flickaway
    MARKETING_VERSION: "0.3.6"
    CURRENT_PROJECT_VERSION: "22"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
    SWIFT_VERSION: "5.9"
    CODE_SIGN_IDENTITY: "-"
    CODE_SIGN_STYLE: Manual
    GENERATE_INFOPLIST_FILE: false
    INFOPLIST_FILE: Info.plist
    LD_RUNPATH_SEARCH_PATHS: "@executable_path/../Frameworks"
    ENABLE_HARDENED_RUNTIME: false
targets:
  FlickAway:
    type: application
    platform: macOS
    sources:
      - path: Sources/FlickAway
    settings:
      base:
        PRODUCT_NAME: Flick Away
        PRODUCT_BUNDLE_IDENTIFIER: com.shashankpatel.flickaway
        INFOPLIST_FILE: Info.plist
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
schemes:
  FlickAway:
    build:
      targets:
        FlickAway: all
    run:
      config: Debug
```

If XcodeGen rejects a key, adjust to the nearest valid XcodeGen 2.x schema while preserving product name, bundle id, sources path, Info.plist, and macOS 13 deployment target.

- [ ] **Step 2: Generate the Xcode project**

```bash
xcodegen generate
```

Expected: creates/updates `FlickAway.xcodeproj` with `project.pbxproj` and a `FlickAway` scheme.

- [ ] **Step 3: Build with xcodebuild**

```bash
xcodebuild -project FlickAway.xcodeproj -scheme FlickAway -configuration Debug -derivedDataPath .build/xcode build
```

Expected: `BUILD SUCCEEDED`.

Verify built app identity:

```bash
app=$(find .build/xcode/Build/Products -name 'Flick Away.app' | head -1)
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist"
```

Expected: `com.shashankpatel.flickaway`.

- [ ] **Step 4: Update .gitignore for Xcode without ignoring the project**

Ensure `.gitignore` contains at least:

```
.build/
.swiftpm/
.DS_Store
DerivedData/
xcuserdata/
*.xcuserstate
*.xccheckout
*.moved-aside
*.hmap
*.ipa
timeline.xctimeline
playground.xcworkspace
```

Do **not** add `FlickAway.xcodeproj` or `project.yml` to `.gitignore`.

- [ ] **Step 5: Commit (only if git + user requested)**

```bash
git add project.yml FlickAway.xcodeproj .gitignore
git commit -m "$(cat <<'EOF'
Add XcodeGen project for Flick Away.

EOF
)"
```

---

### Task 4: Add LICENSE and CONTRIBUTING

**Files:**
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: copyright holder `Shashank Patel`, year `2026`, MIT choice from spec
- Produces: standard liability-limiting license + contributor build notes

- [ ] **Step 1: Write LICENSE**

Create `LICENSE` with the full MIT text:

```
MIT License

Copyright (c) 2026 Shashank Patel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Write CONTRIBUTING.md**

```markdown
# Contributing to Flick Away

## Build

**Script**

```sh
./build.sh
open ".build/Flick Away.app"
```

**Xcode**

Open `FlickAway.xcodeproj`, select the `FlickAway` scheme, then Build or Run.

If you change project structure and have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed, regenerate with:

```sh
xcodegen generate
```

Commit the regenerated `FlickAway.xcodeproj` so contributors do not need XcodeGen.

## Requirements

- macOS 13 or later
- Xcode 15+ or matching Command Line Tools (Swift 5.9+)

## Testing changes

Flick Away needs Accessibility permission and a live Picture-in-Picture window to verify movement, the hover Move button, and the hot-border double-click. After rebuilding, grant Accessibility to the **current** app path if macOS still points at an older copy.

## Scope

Keep pull requests focused. This is a small native utility — avoid drive-by refactors, new dependencies, or unrelated features.
```

- [ ] **Step 3: Commit (only if git + user requested)**

```bash
git add LICENSE CONTRIBUTING.md
git commit -m "$(cat <<'EOF'
Add MIT license and contributing guide.

EOF
)"
```

---

### Task 5: Rewrite README for open source

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: final names/paths from Tasks 1–4 (`./build.sh`, `FlickAway.xcodeproj`, Accessibility flow, features)
- Produces: public README covering what / build / use / limits / license

- [ ] **Step 1: Replace README.md**

Write `README.md` with this content (adjust only if a prior task changed a path/name — keep facts accurate):

```markdown
# Flick Away

Flick Away is a small native macOS menu bar app that moves a video Picture-in-Picture window out of the way when you need to reach something behind it.

## Features

- **Move Window** from the menu bar
- **Global shortcut** (default Control–Option–P; configurable)
- **Move button** on the PiP window when you hover
- **Hot border** — double-click near any edge to move
- **Move modes:** Random or Diagonal
- Optional **tinted border** on the video
- In-app **Accessibility** setup guide when permission is missing

## Requirements

- macOS 13 or later
- Xcode 15 or later, or the matching Command Line Tools (Swift 5.9+)
- No third-party dependencies

## Build

### Using the script

```sh
./build.sh
open ".build/Flick Away.app"
```

This builds a release binary with SwiftPM, wraps it as `Flick Away.app`, and ad-hoc signs it. Optional:

- `FLICKAWAY_BUILD_DIR` — build output directory (default `.build`)
- `FLICKAWAY_SIGN_IDENTITY` — codesign identity (default `-`)

For daily use, move the app to a stable location (for example `/Applications`) before granting Accessibility.

### Using Xcode

1. Open `FlickAway.xcodeproj`
2. Select the **FlickAway** scheme
3. Build or Run

Bundle identifier: `com.shashankpatel.flickaway`.

## Accessibility permission

Flick Away needs Accessibility access to find PiP windows and change their position.

1. Click the four-arrow icon in the menu bar.
2. If permission is missing, choose **Fix** (or the orange warning) and follow the guide.
3. Open **System Settings → Privacy & Security → Accessibility** and enable **Flick Away**.
4. If an older copy is listed after an update, remove it and add the current app.

[Apple’s Accessibility permission guide](https://support.apple.com/guide/mac-help/mh43185/mac)

## How to use

1. Start Picture-in-Picture for a video (Safari, Chrome, or another app that supports PiP).
2. Confirm detection with **Highlight Video Window** in the menu (border pulses).
3. Move the window with any of:
   - **Move Window** in the menu
   - The global shortcut
   - The hover **Move** button
   - Double-click inside the hot border near an edge
4. Choose **Random** or **Diagonal** under **Move mode**. Random is the default; your choice is saved.
5. Toggle **Show "Move" button on video** and **Tint video border** as you like.
6. Use **Change shortcut…** to record a new shortcut (must include Command, Option, or Control). Escape cancels; **Restore default** returns to Control–Option–P.

If several PiP windows are open, hover the one you want, then use the shortcut or button.

## Limitations

- Detection looks for floating windows with PiP Accessibility identifiers or known PiP titles. Localized, custom, or incomplete metadata can be missed.
- The player must allow position changes via Accessibility. If a move fails, check Console logs from subsystem `com.shashankpatel.flickaway`.
- The overlay button and border are separate panels above the video; they can lag briefly after a drag and may hide across Spaces or over full-screen apps.
- Double-clicks on the hot border are also delivered to the player.

## License

MIT License. Copyright (c) 2026 Shashank Patel. See [LICENSE](LICENSE).

The software is provided “as is”, without warranty of any kind. See the license for the full disclaimer of liability.
```

- [ ] **Step 2: Sanity-check README paths exist**

```bash
test -f LICENSE && test -f CONTRIBUTING.md && test -f build.sh && test -d FlickAway.xcodeproj && test -d Sources/FlickAway
rg -n "PiP Flick|PIPFLICK|local\.pipflick" README.md LICENSE CONTRIBUTING.md Info.plist build.sh Package.swift project.yml || true
```

Expected: files exist; no stale `PiP Flick` / old env-var / old bundle-id branding in those packaging files (Swift internal `PiP*` type names in sources are fine).

- [ ] **Step 3: Commit (only if git + user requested)**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
Rewrite README for Flick Away open source release.

EOF
)"
```

---

### Task 6: Final verification

**Files:**
- Verify only (no intentional further edits unless a check fails)

- [ ] **Step 1: Grep for leftover public branding**

```bash
rg -n "PiP Flick|local\.pipflick\.utility|PIPFLICK_|PiP Flick\.app" .
```

Expected: no matches in packaging/UI identity paths. Ignore `.build/`, `docs/superpowers/`, and historical mentions inside the design/plan docs if they describe the migration. Source type names like `PiPWindow` are allowed.

- [ ] **Step 2: Rebuild both paths**

```bash
./build.sh
xcodebuild -project FlickAway.xcodeproj -scheme FlickAway -configuration Debug -derivedDataPath .build/xcode build
```

Expected: both succeed; script output references `Flick Away.app`.

- [ ] **Step 3: Confirm bundle id in both outputs**

```bash
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' ".build/Flick Away.app/Contents/Info.plist"
app=$(find .build/xcode/Build/Products -name 'Flick Away.app' | head -1)
/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist"
```

Expected: both print `com.shashankpatel.flickaway`.

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Full rename to Flick Away | 1, 2, 5 |
| Bundle id `com.shashankpatel.flickaway` | 2, 3 |
| MIT LICENSE, Shashank Patel 2026 | 4 |
| README what/build/use/limits/license | 5 |
| `FlickAway.xcodeproj` compile-ready | 3 |
| `build.sh` still works | 2, 6 |
| CONTRIBUTING + .gitignore | 3, 4 |
| No behavior changes | Global constraint |

## Plan self-review

- No TBD/placeholder steps; full file contents included for LICENSE, README, CONTRIBUTING, `project.yml`, `build.sh`, `Package.swift`.
- Identity strings consistent: `FlickAway` executable/target, `Flick Away` product/app name, `com.shashankpatel.flickaway` bundle id.
- Commit steps gated on git + user request (repo may be uninitialized).
