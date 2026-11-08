import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let standard = Shortcut(keyCode: UInt32(kVK_ANSI_P),
                                   modifiers: UInt32(controlKey | optionKey), keyLabel: "P")
    private static let defaultsKey = "moveShortcut"

    var displayName: String {
        let flags: [(Int, String)] = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
        return flags.filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + keyLabel
    }

    static var saved: Shortcut {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data),
              shortcut.keyCode < 128, !shortcut.keyLabel.isEmpty,
              shortcut.modifiers & UInt32(controlKey | optionKey | cmdKey) != 0 else { return .standard }
        return shortcut
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.defaultsKey) }
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    init(event: NSEvent) throws {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .option, .control]).isEmpty else {
            throw PiPError("Include Command, Option, or Control in your shortcut.")
        }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let labels: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        let label = labels[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !label.isEmpty else { throw PiPError("Try another key.") }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}

final class HotKey {
    private var handler: EventHandlerRef?
    private var registration: EventHotKeyRef?
    private var activeID: UInt32 = 0
    private(set) var shortcut: Shortcut = .standard
    private let action: () -> Void

    init(shortcut: Shortcut, action: @escaping () -> Void) throws {
        self.action = action
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            guard status == noErr, id.signature == 0x50495046, id.id == hotKey.activeID else {
                return OSStatus(eventNotHandledErr)
            }
            hotKey.action()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { throw PiPError("Could not start the keyboard shortcut (\(installed)).") }
        do {
            try update(shortcut)
        } catch {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            throw error
        }
    }

    func update(_ proposed: Shortcut) throws {
        if registration != nil && shortcut == proposed { return }
        let nextID: UInt32 = activeID == 1 ? 2 : 1
        var next: EventHotKeyRef?
        let id = EventHotKeyID(signature: 0x50495046, id: nextID)
        let status = RegisterEventHotKey(proposed.keyCode, proposed.modifiers, id,
                                         GetApplicationEventTarget(), 0, &next)
        guard status == noErr else {
            throw PiPError("Could not use \(proposed.displayName). It may be reserved or already in use. Choose another shortcut.")
        }
        if let registration { UnregisterEventHotKey(registration) }
        registration = next
        activeID = nextID
        shortcut = proposed
    }

    func suspend() {
        if let registration { UnregisterEventHotKey(registration) }
        registration = nil
    }

    func resume() throws { try update(shortcut) }

    deinit {
        suspend()
        if let handler { RemoveEventHandler(handler) }
    }
}
