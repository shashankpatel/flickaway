import AppKit

final class AccessibilityGuide: NSWindowController {
    private let status = NSTextField(labelWithString: "")
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private let openSettings: () -> Void
    private let appURL: URL
    private var lastTrusted: Bool?

    init(appURL: URL = Bundle.main.bundleURL, openSettings: @escaping () -> Void) {
        self.appURL = appURL
        self.openSettings = openSettings
        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 530, height: 610),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Enable Accessibility for Flick Away"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        super.init(window: panel)

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView?.addSubview(content)
        if let view = panel.contentView {
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
                content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
                content.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
                content.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
            ])
        }

        status.font = .systemFont(ofSize: 19, weight: .semibold)
        explanation.font = .systemFont(ofSize: 13)
        explanation.textColor = .secondaryLabelColor
        content.addArrangedSubview(status)
        content.addArrangedSubview(explanation)

        let settings = NSButton(title: "Open Accessibility Settings", target: self,
                                action: #selector(openSettingsClicked))
        settings.bezelStyle = .rounded
        content.addArrangedSubview(settings)

        addStep(to: content, heading: "1. Turn on Flick Away",
                body: "In System Settings, open Privacy & Security → Accessibility. Turn on the switch beside Flick Away. Authenticate if macOS asks.")
        addStep(to: content, heading: "2. If Flick Away is missing",
                body: "Click the + button and add the copy of the app you are running. Use the Finder button below to locate it.")

        let file = NSTextField(wrappingLabelWithString: "This copy: \(appURL.lastPathComponent)")
        file.font = .systemFont(ofSize: 12, weight: .medium)
        file.isSelectable = true
        content.addArrangedSubview(file)
        let finder = NSButton(title: "Show This App in Finder", target: self, action: #selector(showApp))
        finder.bezelStyle = .rounded
        content.addArrangedSubview(finder)

        addStep(to: content, heading: "3. If access is still blocked after an update",
                body: "Select the old Flick Away entry and click − to remove it. Click + and add this copy again. If this window still says access is required, quit Flick Away and reopen this same copy.")

        let note = NSTextField(wrappingLabelWithString:
            "This window stays on top while you follow the steps. The status above updates automatically.")
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabelColor
        content.addArrangedSubview(note)

        let close = NSButton(title: "Close", target: self, action: #selector(closeGuide))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\r"
        let row = NSStackView(views: [NSView(), close])
        row.orientation = .horizontal
        content.addArrangedSubview(row)
        for view in content.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        panel.contentView?.layoutSubtreeIfNeeded()
        let height = max(590, content.fittingSize.height + 48)
        panel.setContentSize(CGSize(width: 530, height: height))
        panel.center()
        update(trusted: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func addStep(to stack: NSStackView, heading: String, body: String) {
        let title = NSTextField(labelWithString: heading)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: body)
        detail.font = .systemFont(ofSize: 13)
        let step = NSStackView(views: [title, detail])
        step.orientation = .vertical
        step.alignment = .leading
        step.spacing = 4
        for view in [title, detail] {
            view.widthAnchor.constraint(equalTo: step.widthAnchor).isActive = true
        }
        stack.addArrangedSubview(step)
    }

    func update(trusted: Bool) {
        guard lastTrusted != trusted else { return }
        lastTrusted = trusted
        status.stringValue = trusted ? "Accessibility is enabled" : "Accessibility access is required"
        status.textColor = trusted ? .systemGreen : .systemOrange
        explanation.stringValue = trusted
            ? "Flick Away can now move your video window. You can close these instructions."
            : "Flick Away needs permission to detect and move video windows. Follow these steps to enable it."
    }

    func present(trusted: Bool) {
        update(trusted: trusted)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettingsClicked() { openSettings() }
    @objc private func showApp() { NSWorkspace.shared.activateFileViewerSelecting([appURL]) }
    @objc private func closeGuide() { close() }
}
