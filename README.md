# PiP Flick

PiP Flick is a small native macOS menu bar app that moves video Picture-in-Picture around its current display. It uses the center of the video to find its current spot and accounts for the menu bar and Dock. **Random** divides the longer side into three and the shorter side into two, then picks any column in a different row. **Diagonal** switches between opposite corners. The default global shortcut is **Control–Option–P**.

## Build and launch

Requires macOS 13 or later and Swift 5.9 or later from Xcode 15 or later or the corresponding Command Line Tools. The app has no external dependencies.

From the extracted project folder in Terminal:

```sh
./build.sh
open ".build/PiP Flick.app"
```

The script builds a native Swift executable, wraps it in an app bundle, and signs the bundle locally. To build from Xcode, open `Package.swift` to browse the source and use the script to create the app bundle. For daily use, move the built app to a stable location before granting permission. The script uses an ad-hoc signature by default and accepts an optional signing identity in `PIPFLICK_SIGN_IDENTITY`.

## Grant Accessibility access

1. Open the **four-arrow move icon** in the menu bar. If permission is missing, the menu shows an orange **Accessibility access required** warning and **Fix**.
2. Click **Fix** to open a floating instructions window. It stays above other normal windows while you follow the steps.
3. Click **Open Accessibility Settings**. In **System Settings → Privacy & Security → Accessibility**, turn on **PiP Flick**.
4. If the app is missing, use **Show This App in Finder** to locate the current copy, then add it with **+** in Accessibility settings.
5. If an older entry is enabled after an update but access is still missing, remove that entry and add the current copy. Reopen PiP Flick if needed.

The guide checks access automatically and shows **Accessibility is enabled** when ready. The menu warning disappears as soon as access is available. Close the guide with its **Close** button.

Accessibility lets PiP Flick inspect window metadata and request a position change. The app registers one global shortcut and performs its window checks locally. [Apple’s Accessibility permission instructions](https://support.apple.com/en-au/guide/mac-help/mh43185/mac)

## Verify PiP on your Mac

1. Open a single video in PiP. In Safari, right-click the speaker icon in the address bar while audio is playing and choose **Enter Picture in Picture**. Safari’s Page Menu may also offer PiP. In Chrome on YouTube, right-click the video twice and choose **Picture in Picture** from Chrome’s context menu. [Apple’s Safari PiP guide](https://support.apple.com/en-au/guide/safari/ibrw27291639/mac)
2. Open **Highlight Video Window** in the move icon’s menu. The border pulses three times to identify the detected window, and the status reports whether its position is writable.
3. Choose **Move Window** or press **Control–Option–P**. Select **Random** or **Diagonal** under **Move mode**. Random is the default and the app remembers your choice. Reopen the move icon’s menu after the move to see the result. If multiple PiP windows are open, hover over the one you want to move and use the shortcut.
4. Hover over a recognized window with a writable position to reveal the outline and its continuous curved tab. With tint off, the tab is black with a white four-arrow icon. It sits at the bottom center for a video in the upper half of the screen, or at the top center for a video in the lower half. **Show "Move" button on video** toggles the tab.
5. Enable **Tint video border** to fill the 18-point band inside the video with light gray. This preference starts off and is saved. The tab stays visible on hover with tinting off.
6. Double-click within 18 points of any edge to move the video using the selected mode. The player also receives the clicks. [Apple’s event-monitoring documentation](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:))
7. Manually dragging the video hides the tab and border until release. Clicking the tab hides it immediately, then starts the move.

## Shortcut and version

Choose **Change shortcut…** from the menu. Click the shortcut field, then press the combination you want to use. Include Command, Option, or Control. Escape cancels recording, and **Restore default** selects Control–Option–P. A shortcut already in use is rejected. Your saved choice is restored when the app starts.

The menu shows the app version in **About PiP Flick**. Open that item for the version and build number.

## Browser scope and limitations

- **Shared detection.** PiP Flick matches visible floating window geometry against Accessibility windows with the `picture-in-picture` identifier or an exact English PiP title. Safari uses the macOS PiP agent, which can also host video from other apps. Detection can miss windows with localized or custom titles, incomplete Accessibility metadata, or window layers outside the floating range. [Apple’s window metadata reference](https://developer.apple.com/documentation/coregraphics/required-window-list-keys)
- **Position writes.** The app checks whether `AXPosition` is writable, then moves the window with a short glide. If Reduce Motion is enabled or the player rejects an intermediate position, it requests the destination directly. The final read-back must be within two points on each axis of the requested position. Movement diagnostics are written to the system log. [Apple’s Accessibility API reference](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- **Button on video.** The button and click-through outline are separate AppKit panels, drawn above the video. Both hide when the pointer leaves the window and button. Placement can lag briefly after a drag, and the panels may disappear across Spaces or in full-screen apps. [AppKit window levels](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct)

## Build verification

The preview builds on Apple silicon with Swift 6.4.2 on macOS 27.0.1. Safari's live PiP window was observed in the macOS PiP agent, with the `picture-in-picture` Accessibility identifier. End-to-end movement and the overlay in this preview still need verification with the built app's Accessibility permission.
