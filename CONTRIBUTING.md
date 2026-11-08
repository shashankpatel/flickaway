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
