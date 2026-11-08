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
