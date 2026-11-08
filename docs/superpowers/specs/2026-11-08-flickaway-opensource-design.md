# Flick Away — Open Source Packaging Design

**Date:** 2026-11-08  
**Status:** Approved for implementation after user review of this spec  
**Copyright holder:** Shashank Patel  
**License:** MIT

## Goal

Prepare the existing macOS PiP utility for public open source as **Flick Away**: clear README and usage docs, MIT license (no warranty / no liability), full product rename, and a compile-ready Xcode project alongside the existing `build.sh` / SwiftPM flow.

## Product summary

Flick Away is a native macOS menu bar app. When a video Picture-in-Picture window is on screen, it helps you quickly move that window out of the way so you can reach what’s behind it. Interaction options:

- Menu bar **Move Window** action
- Global shortcut (default Control–Option–P; user-configurable)
- Hover **Move** button on the video
- Double-click within the hot border band near any edge
- Move modes: **Random** and **Diagonal**
- Optional tinted video border; Accessibility permission guide in-app

Requires Accessibility access. No third-party dependencies. macOS 13+.

## Approach

**Docs + full rename + hand-made Xcode project**, keeping SwiftPM + `build.sh` as the CLI path.

Rejected alternatives:

- Xcode-only as sole source of truth (more invasive; hurts script-based builds)
- Docs-only without rename (conflicts with “Flick Away everywhere”)

## Naming & identity

| Item | Value |
|------|--------|
| Product name | Flick Away |
| Bundle display / app name | Flick Away |
| App bundle | `Flick Away.app` |
| Bundle identifier | `com.shashankpatel.flickaway` |
| Executable | `FlickAway` |
| Swift package / target | `FlickAway` |
| Source directory | `Sources/FlickAway/` |
| Logger subsystem | `com.shashankpatel.flickaway` |
| Xcode project | `FlickAway.xcodeproj` (repo root) |

User-facing strings currently saying “PiP Flick” become “Flick Away”.

Internal type names that are not user-visible (`PiPDiscovery`, `PiPWindow`, `PiPError`, etc.) may remain unchanged.

Build script environment variables:

- `FLICKAWAY_BUILD_DIR` (scratch / output root; default `.build`)
- `FLICKAWAY_SIGN_IDENTITY` (codesign identity; default ad-hoc `-`)

Clean break from old `PIPFLICK_*` names (no aliases required).

## File layout (target)

```
LICENSE
README.md
CONTRIBUTING.md
.gitignore
Info.plist
Package.swift
build.sh
Sources/FlickAway/
  AccessibilityGuide.swift
  BrowserPiP.swift
  HotKey.swift
  Overlay.swift
  ShortcutSettings.swift
  main.swift
FlickAway.xcodeproj/
docs/superpowers/specs/2026-11-08-flickaway-opensource-design.md
```

Remove / replace `Sources/PiPFlick/` after the move.

## Info.plist

Update (keep version numbers unless intentionally bumped):

- `CFBundleExecutable` → `FlickAway`
- `CFBundleIdentifier` → `com.shashankpatel.flickaway`
- `CFBundleName` → `Flick Away`
- Retain `LSUIElement` = true, `LSMinimumSystemVersion` = 13.0, existing version/build strings unless a deliberate release bump is added during implementation

## Xcode project

- Single macOS App target `FlickAway`
- Product name `Flick Away`
- Bundle ID `com.shashankpatel.flickaway`
- Deployment target macOS 13.0
- Compile all sources under `Sources/FlickAway/`
- Use root `Info.plist`
- System frameworks as needed: AppKit, ApplicationServices, Carbon, OSLog
- No SPM package dependencies in the app target
- Code signing: local / automatic / ad-hoc friendly so contributors can Build & Run without a paid team
- Shared scheme `FlickAway` so open → build/run works

`build.sh` remains the SwiftPM release build + app-bundle wrap + codesign path. Both paths must agree on product name, bundle id, and executable name.

## README content

Rewrite for open-source users (clearer than current lab-style notes):

1. Title and one-liner
2. Features
3. Requirements (macOS 13+, Xcode 15+ / CLT, Swift 5.9+)
4. Build via `./build.sh` and via `FlickAway.xcodeproj`
5. First launch / Accessibility permission (in-app Fix flow)
6. How to use (PiP setup, move actions, overlay, hot border, modes, shortcut)
7. Limitations (detection / Accessibility / overlay edge cases)
8. License pointer (MIT)

## Other open-source files

- **LICENSE** — MIT, Copyright (c) 2026 Shashank Patel
- **CONTRIBUTING.md** — how to build, keep changes focused, note Accessibility testing needs a real PiP window
- **.gitignore** — keep `.build/`, `.swiftpm/`, `.DS_Store`; add Xcode noise (`xcuserdata/`, `DerivedData/`, `*.xcuserstate`, etc.)

Out of scope unless requested later: CODE_OF_CONDUCT, CI workflows, notarization docs, app icon asset catalog, App Store packaging.

## Implementation notes

- Prefer mechanical rename + packaging files; avoid behavior changes.
- After rename, verify `build.sh` still produces a signed `Flick Away.app`.
- Prefer verifying the Xcode project opens and the target settings match Identity table above; full GUI Run is optional if environment allows.
- Do not invent new features in this pass.

## Success criteria

- Someone cloning the repo can understand what Flick Away is and how to use it from the README alone.
- MIT LICENSE is present with Shashank Patel copyright.
- Bundle id is `com.shashankpatel.flickaway` everywhere identity is declared.
- Product is named Flick Away in user-facing surfaces and packaging.
- Users can build with `./build.sh` or by opening `FlickAway.xcodeproj`.
