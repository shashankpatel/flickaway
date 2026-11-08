import AppKit
import ApplicationServices
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let browser = PiPDiscovery()
    private let logger = Logger(subsystem: "local.pipflick.utility", category: "Movement")
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let shortcutStatus = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessStatusItem = NSMenuItem(title: "Accessibility access required", action: nil, keyEquivalent: "")
    private lazy var fixAccessItem = menuItem("Fix", #selector(showAccessibilityGuide))
    private let accessSeparator = NSMenuItem.separator()
    private let moveModeMenu = NSMenu(title: "Move mode")
    private let moveModeKey = "moveMode"
    private var moveMode: MoveMode {
        MoveMode(rawValue: UserDefaults.standard.string(forKey: moveModeKey) ?? "") ?? .random
    }
    private lazy var overlayItem = menuItem("Show \"Move\" button on video", #selector(toggleOverlay))
    private lazy var tintItem = menuItem("Tint video border", #selector(toggleTint))
    private var tintsBorder: Bool { UserDefaults.standard.bool(forKey: "tintVideoBorder") }
    private lazy var overlay = Overlay(target: self, action: #selector(moveFromOverlay))
    private var hotKey: HotKey?
    private var shortcutSettings: ShortcutSettings?
    private var accessibilityGuide: AccessibilityGuide?
    private var edgeMonitor: Any?
    private var overlayWindow: AXUIElement?
    private var overlayTimer: Timer?
    private var moveInProgress = false
    private var manualPressPoint: CGPoint?
    private var manualDragTimer: Timer?
    private var isManualDragging = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = ""
        let icon = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right",
                           accessibilityDescription: "PiP Flick")
        let menuIcon = icon?.withSymbolConfiguration(.init(pointSize: 15, weight: .medium)) ?? icon
        menuIcon?.isTemplate = true
        statusItem.button?.image = menuIcon
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.setAccessibilityLabel("PiP Flick")
        statusItem.button?.toolTip = "PiP Flick"

        let menu = NSMenu()
        menu.delegate = self
        accessStatusItem.attributedTitle = NSAttributedString(
            string: "Accessibility access required",
            attributes: [.foregroundColor: NSColor.systemOrange,
                         .font: NSFont.menuFont(ofSize: 0)])
        accessStatusItem.target = self
        accessStatusItem.action = #selector(showAccessibilityGuide)
        let warning = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                              accessibilityDescription: "Permission required")
        accessStatusItem.image = warning?.withSymbolConfiguration(.init(paletteColors: [.systemOrange]))
        accessStatusItem.image?.isTemplate = false
        menu.addItem(accessStatusItem)
        menu.addItem(fixAccessItem)
        menu.addItem(accessSeparator)
        menu.addItem(menuItem("Move Window", #selector(movePiP)))
        let moveModeItem = NSMenuItem(title: "Move mode", action: nil, keyEquivalent: "")
        for mode in MoveMode.allCases {
            let item = menuItem(mode.rawValue.capitalized, #selector(selectMoveMode(_:)))
            item.representedObject = mode.rawValue
            moveModeMenu.addItem(item)
        }
        moveModeItem.submenu = moveModeMenu
        menu.addItem(moveModeItem)
        updateMoveModeMenu()
        menu.addItem(menuItem("Highlight Video Window", #selector(checkPiP)))
        menu.addItem(overlayItem)
        tintItem.state = tintsBorder ? .on : .off
        menu.addItem(tintItem)
        menu.addItem(menuItem("Change shortcut…", #selector(openShortcutSettings)))
        menu.addItem(.separator())
        menu.addItem(shortcutStatus)
        menu.addItem(menuItem("Accessibility Settings…", #selector(openAccessibilitySettings)))
        menu.addItem(.separator())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        menu.addItem(menuItem("About PiP Flick \(version)…", #selector(showAbout)))
        menu.addItem(menuItem("Quit", #selector(quit)))
        statusItem.menu = menu
        _ = updateAccessibilityStatus()

        do {
            hotKey = try HotKey(shortcut: .saved) { [weak self] in self?.movePiP() }
            updateShortcutStatus()
        } catch {
            shortcutStatus.title = error.localizedDescription
        }
        edgeMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        overlayItem.state = .on
        let timer = Timer(timeInterval: 0.5, target: self,
                          selector: #selector(refreshOverlay), userInfo: nil, repeats: true)
        overlayTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refreshOverlay()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let edgeMonitor { NSEvent.removeMonitor(edgeMonitor) }
        overlayTimer?.invalidate()
        stopManualDrag()
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func report(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    func menuWillOpen(_ menu: NSMenu) {
        _ = updateAccessibilityStatus()
    }

    @discardableResult
    private func updateAccessibilityStatus() -> Bool {
        let trusted = AXIsProcessTrusted()
        accessStatusItem.isHidden = trusted
        fixAccessItem.isHidden = trusted
        accessSeparator.isHidden = trusted
        statusItem.button?.toolTip = trusted ? "PiP Flick" : "PiP Flick — Accessibility access required"
        accessibilityGuide?.update(trusted: trusted)
        if !trusted {
            stopManualDrag()
            hideOverlay()
        }
        return trusted
    }

    private func ensureAccessibility() -> Bool {
        guard updateAccessibilityStatus() else {
            showAccessibilityGuide()
            return false
        }
        return true
    }

    @objc private func showAccessibilityGuide() {
        if accessibilityGuide == nil {
            accessibilityGuide = AccessibilityGuide { [weak self] in self?.openAccessibilitySettings() }
        }
        accessibilityGuide?.present(trusted: AXIsProcessTrusted())
    }

    @objc private func checkPiP() {
        guard !moveInProgress, ensureAccessibility() else { return }
        do {
            let window = try browser.findWindow(preferred: overlayWindow)
            overlayWindow = window.element
            overlay.track(window, showButton: overlayItem.state == .on, tintBorder: tintsBorder)
            overlay.flash()
            do {
                try AX.requireWritablePosition(window.element)
                report("\(window.source.rawValue) found and highlighted. Position is writable.")
            } catch {
                report(error.localizedDescription)
            }
        } catch {
            hideOverlay()
            report(error.localizedDescription)
            let alert = NSAlert()
            alert.messageText = "Couldn’t find a PiP window"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func movePiP() { switchCorner() }

    private func updateShortcutStatus() {
        shortcutStatus.title = "Shortcut: \(Shortcut.saved.displayName)"
    }

    @objc private func openShortcutSettings() {
        if shortcutSettings == nil {
            shortcutSettings = ShortcutSettings(shortcut: .saved, save: { [weak self] proposed in
                guard let self else { return }
                if let hotKey = self.hotKey {
                    try hotKey.update(proposed)
                } else {
                    self.hotKey = try HotKey(shortcut: proposed) { [weak self] in self?.movePiP() }
                }
                proposed.save()
                self.updateShortcutStatus()
            }, recordingChanged: { [weak self] recording in
                guard let self else { return }
                if recording {
                    self.hotKey?.suspend()
                } else {
                    do { try self.hotKey?.resume() }
                    catch { self.shortcutStatus.title = error.localizedDescription }
                }
            })
        }
        shortcutSettings?.present()
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "PiP Flick",
                                                    .applicationVersion: "\(version) (\(build))"])
    }

    @objc private func selectMoveMode(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String, let mode = MoveMode(rawValue: value) else { return }
        UserDefaults.standard.set(mode.rawValue, forKey: moveModeKey)
        updateMoveModeMenu()
    }

    private func updateMoveModeMenu() {
        let selection = moveMode.rawValue
        for item in moveModeMenu.items {
            item.state = (item.representedObject as? String) == selection ? .on : .off
        }
    }

    @objc private func moveFromOverlay() {
        guard let overlayWindow else { return }
        switchCorner(requiring: overlayWindow)
    }

    private func handleEdgeDoubleClick(_ event: NSEvent) {
        guard !moveInProgress, event.clickCount == 2, let primary = NSScreen.screens.first else { return }
        let pointer = NSEvent.mouseLocation
        let point = event.cgEvent?.location ?? CGPoint(x: pointer.x, y: primary.frame.maxY - pointer.y)
        guard let window = try? browser.findWindow(at: point),
              Placement.isInEdgeBand(point, of: window.frame) else { return }
        move(window)
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard AXIsProcessTrusted(), !moveInProgress, let primary = NSScreen.screens.first else {
            stopManualDrag()
            return
        }
        let pointer = NSEvent.mouseLocation
        let point = event.cgEvent?.location ?? CGPoint(x: pointer.x, y: primary.frame.maxY - pointer.y)
        switch event.type {
        case .leftMouseDown:
            stopManualDrag()
            guard (try? browser.findWindow(at: point)) != nil else { return }
            manualPressPoint = point
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                self?.pollManualDrag()
            }
            manualDragTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        case .leftMouseDragged:
            pollManualDrag()
        case .leftMouseUp:
            let wasDragging = isManualDragging
            stopManualDrag()
            if wasDragging {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.refreshOverlay()
                }
            } else {
                handleEdgeDoubleClick(event)
            }
        default:
            break
        }
    }

    private func pollManualDrag() {
        guard let start = manualPressPoint, let primary = NSScreen.screens.first else { return }
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            stopManualDrag()
            refreshOverlay()
            return
        }
        let pointer = NSEvent.mouseLocation
        let point = CGPoint(x: pointer.x, y: primary.frame.maxY - pointer.y)
        if !isManualDragging && hypot(point.x - start.x, point.y - start.y) > 4 {
            isManualDragging = true
            hideOverlay()
        }
    }

    private func stopManualDrag() {
        manualDragTimer?.invalidate()
        manualDragTimer = nil
        manualPressPoint = nil
        isManualDragging = false
    }

    private func switchCorner(requiring expectedWindow: AXUIElement? = nil) {
        guard !moveInProgress, ensureAccessibility() else { return }
        moveInProgress = true
        stopManualDrag()
        hideOverlay()
        // Yield after hiding so the tab disappears before any window lookup can block.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self else { return }
            do {
                let window = try self.browser.findWindow(preferred: expectedWindow)
                if let expectedWindow, !CFEqual(expectedWindow, window.element) {
                    throw PiPError("PiP changed. Wait for the tab to follow the new video.")
                }
                self.move(window)
            } catch {
                self.moveInProgress = false
                self.report(error.localizedDescription)
            }
        }
    }

    private func move(_ window: PiPWindow) {
        do {
            try AX.requireWritablePosition(window.element)
            let destination = try Placement.destination(for: window.frame, mode: moveMode)
            guard hypot(destination.point.x - window.frame.minX,
                        destination.point.y - window.frame.minY) > 2 else {
                moveInProgress = false
                return
            }
            moveInProgress = true
            hideOverlay()
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                finishMove(of: window, to: destination)
            } else {
                glide(of: window, to: destination)
            }
        } catch {
            moveInProgress = false
            hideOverlay()
            report(error.localizedDescription)
        }
    }

    private func glide(of window: PiPWindow, to destination: Placement.Move) {
        let duration = 0.30
        let startedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
            if elapsed < duration {
                let point = destination.glidePosition(from: window.frame.origin,
                                                      progress: CGFloat(elapsed / duration))
                do {
                    try AX.move(window.element, to: point)
                    return
                } catch {
                    // Try the final position if the player rejects an intermediate update.
                }
            }
            timer.invalidate()
            self.finishMove(of: window, to: destination)
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finishMove(of window: PiPWindow, to destination: Placement.Move) {
        do {
            try AX.move(window.element, to: destination.point)
            report("\(window.source.rawValue) accepted the move request. Checking the resulting position…")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
                self?.verifyMove(of: window, to: destination)
            }
        } catch {
            moveInProgress = false
            report(error.localizedDescription)
        }
    }

    private func verifyMove(of window: PiPWindow, to destination: Placement.Move) {
        defer { moveInProgress = false }
        do {
            let actual = try AX.position(window.element)
            let start = window.frame.origin
            let target = destination.point
            let reachedTarget = abs(actual.x - target.x) <= 2 && abs(actual.y - target.y) <= 2
            let actualFrame = CGRect(origin: actual, size: window.frame.size)
            let snappedToSlot = window.source == .system &&
                destination.grid.visible.contains(CGPoint(x: actualFrame.midX, y: actualFrame.midY)) &&
                destination.grid.slot(for: actualFrame) == destination.slot
            let moved = hypot(actual.x - start.x, actual.y - start.y) > 2
            guard reachedTarget || snappedToSlot, moved else {
                throw PiPError("Move unverified. From \(describe(start)), requested \(describe(target)), read \(describe(actual)).")
            }
            let spot = destination.grid.name(of: destination.slot)
            report("Verified \(window.source.rawValue) move to \(spot): \(describe(start)) → \(describe(actual)).")
        } catch {
            report(error.localizedDescription)
        }
    }

    private func describe(_ point: CGPoint) -> String {
        String(format: "(%.0f, %.0f)", point.x, point.y)
    }

    private func hideOverlay() {
        guard overlayWindow != nil else { return }
        overlayWindow = nil
        overlay.hide()
    }

    @objc private func toggleTint() {
        UserDefaults.standard.set(!tintsBorder, forKey: "tintVideoBorder")
        tintItem.state = tintsBorder ? .on : .off
        refreshOverlay()
    }

    @objc private func toggleOverlay() {
        overlayItem.state = overlayItem.state == .on ? .off : .on
        refreshOverlay()
    }

    @objc private func refreshOverlay() {
        guard updateAccessibilityStatus(), !moveInProgress, !isManualDragging else { return }
        let preferred = overlayWindow != nil && (overlay.isPointerOverButton || overlay.isFlashing)
            ? overlayWindow : nil
        guard let window = try? browser.findWindow(preferred: preferred) else {
            hideOverlay()
            return
        }
        guard overlay.isFlashing || (try? AX.requireWritablePosition(window.element)) != nil else {
            hideOverlay()
            return
        }
        overlayWindow = window.element
        overlay.track(window, showButton: overlayItem.state == .on, tintBorder: tintsBorder)
    }

    @objc private func openAccessibilitySettings() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
