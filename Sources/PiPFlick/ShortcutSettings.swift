import AppKit

final class ShortcutSettings: NSWindowController, NSWindowDelegate {
    private let recorder = NSButton()
    private let message = NSTextField(wrappingLabelWithString: "")
    private var monitor: Any?
    private var shortcut: Shortcut
    private let saveShortcut: (Shortcut) throws -> Void
    private let recordingChanged: (Bool) -> Void

    init(shortcut: Shortcut, save: @escaping (Shortcut) throws -> Void,
         recordingChanged: @escaping (Bool) -> Void) {
        self.shortcut = shortcut
        saveShortcut = save
        self.recordingChanged = recordingChanged
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 440, height: 250),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "PiP Flick Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self

        let heading = NSTextField(labelWithString: "Move shortcut")
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        heading.frame = CGRect(x: 28, y: 197, width: 384, height: 24)
        let instructions = NSTextField(wrappingLabelWithString:
            "Click the shortcut, then press a key with Command, Option, or Control. Press Escape to cancel.")
        instructions.textColor = .secondaryLabelColor
        instructions.frame = CGRect(x: 28, y: 143, width: 384, height: 44)
        recorder.title = shortcut.displayName
        recorder.bezelStyle = .rounded
        recorder.font = .systemFont(ofSize: 20, weight: .medium)
        recorder.frame = CGRect(x: 28, y: 89, width: 384, height: 44)
        recorder.target = self
        recorder.action = #selector(toggleRecording)
        recorder.setAccessibilityLabel("Record move shortcut")
        message.font = .systemFont(ofSize: 12)
        message.frame = CGRect(x: 28, y: 42, width: 384, height: 42)

        let reset = NSButton(title: "Restore default", target: self, action: #selector(restoreDefault))
        reset.bezelStyle = .rounded
        reset.frame = CGRect(x: 24, y: 8, width: 146, height: 30)
        for view in [heading, instructions, recorder, message, reset] {
            window.contentView?.addSubview(view)
        }
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleRecording() {
        if monitor != nil { stopRecording(); return }
        message.stringValue = ""
        recorder.title = "Press shortcut…"
        recordingChanged(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            if event.keyCode == 53 {
                self.stopRecording()
            } else if !event.isARepeat {
                do { try self.apply(Shortcut(event: event)) }
                catch { self.message.stringValue = error.localizedDescription }
            }
            return nil
        }
        if monitor == nil {
            stopRecording()
            message.stringValue = "Could not start recording. Try again."
        }
    }

    private func apply(_ proposed: Shortcut) throws {
        try saveShortcut(proposed)
        shortcut = proposed
        stopRecording()
        message.stringValue = "Shortcut saved."
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recorder.title = shortcut.displayName
        recordingChanged(false)
    }

    @objc private func restoreDefault() {
        do { try apply(.standard) }
        catch { message.stringValue = error.localizedDescription }
    }

    func windowWillClose(_ notification: Notification) { stopRecording() }
    func windowDidResignKey(_ notification: Notification) { stopRecording() }
}
