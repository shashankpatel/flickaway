import AppKit
import ApplicationServices

struct PiPWindow {
    let element: AXUIElement
    let frame: CGRect
    let source: PiPSource
    let layer: Int
}

enum PiPSource: String {
    case chrome = "Chrome PiP"
    case system = "macOS PiP"
    case floating = "Video PiP"

    init(bundleID: String?) {
        switch bundleID {
        case "com.google.Chrome": self = .chrome
        case "com.apple.PIPAgent": self = .system
        default: self = .floating
        }
    }
}

struct PiPError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct PiPDiscovery {
    var usesAppSpecificAdjustments = false

    private struct FloatingWindow {
        let index: Int
        let pid: pid_t
        let frame: CGRect
        let layer: Int
    }

    func findWindow(preferred: AXUIElement? = nil, at point: CGPoint? = nil) throws -> PiPWindow {
        guard AXIsProcessTrusted() else {
            throw PiPError("Enable Flick Away in System Settings → Privacy & Security → Accessibility.")
        }
        let floating = onScreenFloatingWindows().filter { window in
            guard let point else { return true }
            return window.frame.contains(point)
        }
        let byOwner = Dictionary(grouping: floating, by: \.pid)
        var matches: [(index: Int, window: PiPWindow)] = []
        for (pid, candidates) in byOwner {
            let source = usesAppSpecificAdjustments
                ? PiPSource(bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier)
                : .floating
            for element in AX.windows(for: pid) where isPiP(element) {
                guard let frame = try? AX.frame(element),
                      let candidate = candidates.first(where: { Self.framesMatch($0.frame, frame) })
                else { continue }
                if let point, !frame.contains(point) { continue }
                matches.append((candidate.index, PiPWindow(element: element, frame: frame,
                                                           source: source, layer: candidate.layer)))
            }
        }
        guard let first = matches.first else {
            throw PiPError("No recognizable video PiP window found.")
        }
        if let preferred, let match = matches.first(where: { CFEqual($0.window.element, preferred) }) {
            return match.window
        }
        if point != nil { return matches.min(by: { $0.index < $1.index })?.window ?? first.window }
        guard matches.count > 1 else { return first.window }

        if let primary = NSScreen.screens.first {
            let pointer = NSEvent.mouseLocation
            let hovered = matches.filter {
                Placement.appKitRect($0.window.frame, primaryTop: primary.frame.maxY).contains(pointer)
            }
            if let front = hovered.min(by: { $0.index < $1.index }) { return front.window }
        }
        throw PiPError("Multiple PiP windows are open. Hover over one and use the move shortcut.")
    }

    private func onScreenFloatingWindows() -> [FloatingWindow] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                             kCGNullWindowID) as? [[String: Any]] ?? []
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let floatingLevel = Int(CGWindowLevelForKey(.floatingWindow))
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        return info.enumerated().compactMap { index, window in
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer >= floatingLevel, layer < statusLevel,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  !frame.isEmpty else { return nil }
            return FloatingWindow(index: index, pid: pid, frame: frame, layer: layer)
        }
    }

    private func isPiP(_ element: AXUIElement) -> Bool {
        let identifier = (try? AX.read(element, kAXIdentifierAttribute)) as? String
        let title = (try? AX.read(element, kAXTitleAttribute)) as? String
        return Self.isPiP(identifier: identifier, title: title)
    }

    static func isPiP(identifier: String?, title: String?) -> Bool {
        if identifier?.lowercased() == "picture-in-picture" { return true }
        let normalized = title?.lowercased().replacingOccurrences(of: "-", with: " ")
        return normalized == "picture in picture"
    }

    static func framesMatch(_ first: CGRect, _ second: CGRect) -> Bool {
        abs(first.minX - second.minX) <= 2 && abs(first.minY - second.minY) <= 2 &&
        abs(first.maxX - second.maxX) <= 2 && abs(first.maxY - second.maxY) <= 2
    }
}

enum AX {
    static func windows(for pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        return (try? read(app, kAXWindowsAttribute)) as? [AXUIElement] ?? []
    }

    static func read(_ element: AXUIElement, _ attribute: String) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        try check(result, "Reading \(attribute)")
        return value
    }

    static func geometry<T>(_ element: AXUIElement, _ attribute: String,
                            _ type: AXValueType, initial: T) throws -> T {
        guard let value = try read(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else {
            throw PiPError("The PiP window returned no usable \(attribute).")
        }
        let geometry = value as! AXValue
        var result = initial
        guard AXValueGetType(geometry) == type,
              withUnsafeMutablePointer(to: &result, { AXValueGetValue(geometry, type, $0) }) else {
            throw PiPError("The PiP window returned an unexpected \(attribute) format.")
        }
        return result
    }

    static func position(_ element: AXUIElement) throws -> CGPoint {
        let origin: CGPoint = try geometry(element, kAXPositionAttribute, .cgPoint, initial: .zero)
        guard origin.x.isFinite, origin.y.isFinite else {
            throw PiPError("The PiP window returned an invalid position.")
        }
        return origin
    }

    static func frame(_ element: AXUIElement) throws -> CGRect {
        let origin = try position(element)
        let size: CGSize = try geometry(element, kAXSizeAttribute, .cgSize, initial: .zero)
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            throw PiPError("The PiP window returned an invalid size.")
        }
        return CGRect(origin: origin, size: size)
    }

    static func requireWritablePosition(_ element: AXUIElement) throws {
        var writable = DarwinBoolean(false)
        try check(AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &writable),
                  "Checking AXPosition writability")
        guard writable.boolValue else {
            throw PiPError("macOS reported this PiP window’s position as read-only.")
        }
    }

    static func move(_ element: AXUIElement, to target: CGPoint) throws {
        var point = target
        guard let value = AXValueCreate(.cgPoint, &point) else {
            throw PiPError("Could not encode the target position.")
        }
        try check(AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value),
                  "Writing AXPosition")
    }

    private static func check(_ result: AXError, _ operation: String) throws {
        guard result == .success else {
            throw PiPError("\(operation) failed (AX error \(result.rawValue)).")
        }
    }
}

enum MoveMode: String, CaseIterable {
    case random
    case diagonal
}

enum Placement {
    struct Slot: Equatable {
        let column: Int
        let row: Int
    }

    struct Grid {
        let visible: CGRect
        let columns: Int
        let rows: Int

        init(visible: CGRect, mode: MoveMode) {
            self.visible = visible
            let isLandscape = visible.width >= visible.height
            columns = mode == .random && isLandscape ? 3 : 2
            rows = mode == .random && !isLandscape ? 3 : 2
        }

        func slot(for frame: CGRect) -> Slot {
            // Accessibility coordinates increase downward from the top of the display.
            let x = (frame.midX - visible.minX) / visible.width
            let y = (frame.midY - visible.minY) / visible.height
            return Slot(column: index(for: x, count: columns), row: index(for: y, count: rows))
        }

        func name(of slot: Slot) -> String {
            let row = slot.row == 0 ? "top" : (slot.row == rows - 1 ? "bottom" : "middle")
            let column = slot.column == 0 ? "left" : (slot.column == columns - 1 ? "right" : "center")
            return "\(row)-\(column)"
        }

        private func index(for fraction: CGFloat, count: Int) -> Int {
            let scaled = min(1, max(0, fraction)) * CGFloat(count)
            return max(0, Int(scaled.rounded(.up)) - 1)
        }
    }

    struct Move {
        let point: CGPoint
        let slot: Slot
        let grid: Grid

        func glidePosition(from start: CGPoint, progress: CGFloat) -> CGPoint {
            let time = min(1, max(0, progress))
            let eased = time * time * (3 - 2 * time)
            return CGPoint(x: start.x + (point.x - start.x) * eased,
                           y: start.y + (point.y - start.y) * eased)
        }
    }

    static func appKitRect(_ rect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }

    static func isInEdgeBand(_ point: CGPoint, of frame: CGRect) -> Bool {
        frame.contains(point) && !edgeBandInterior(of: frame).contains(point)
    }

    static func edgeBandInterior(of frame: CGRect) -> CGRect {
        frame.insetBy(dx: 18, dy: 18)
    }

    static func screen(for frame: CGRect, primaryTop: CGFloat) -> NSScreen? {
        let window = appKitRect(frame, primaryTop: primaryTop)
        return NSScreen.screens
            .map { screen -> (NSScreen, CGFloat) in
                let intersection = window.intersection(screen.frame)
                return (screen, intersection.isNull ? 0 : intersection.width * intersection.height)
            }
            .filter { $0.1 > 0 }
            .max(by: { $0.1 < $1.1 })?.0
    }

    private static func visibleArea(for frame: CGRect) throws -> CGRect {
        guard let primary = NSScreen.screens.first,
              let screen = screen(for: frame, primaryTop: primary.frame.maxY) else {
            throw PiPError("PiP is outside the connected displays.")
        }
        return appKitRect(screen.visibleFrame, primaryTop: primary.frame.maxY)
    }

    static func destination(for frame: CGRect, mode: MoveMode) throws -> Move {
        try destination(for: frame, within: visibleArea(for: frame), mode: mode)
    }

    static func destination(for frame: CGRect, within visible: CGRect, mode: MoveMode) throws -> Move {
        let grid = Grid(visible: visible, mode: mode)
        let current = grid.slot(for: frame)
        let next: Slot
        switch mode {
        case .random:
            let rowIndex = Int.random(in: 0..<(grid.rows - 1))
            let row = rowIndex < current.row ? rowIndex : rowIndex + 1
            let column = Int.random(in: 0..<grid.columns)
            next = Slot(column: column, row: row)
        case .diagonal:
            next = Slot(column: grid.columns - 1 - current.column, row: grid.rows - 1 - current.row)
        }
        return try move(frame, to: next, in: grid)
    }

    private static func move(_ frame: CGRect, to next: Slot, in grid: Grid) throws -> Move {
        let visible = grid.visible
        let horizontalRoom = visible.width - frame.width
        let verticalRoom = visible.height - frame.height
        guard horizontalRoom > 4, verticalRoom > 4 else {
            throw PiPError("The display’s usable area is too small to move this PiP window.")
        }
        let horizontalMargin = min(12, horizontalRoom / 4)
        let verticalMargin = min(12, verticalRoom / 4)
        let first = CGPoint(x: (visible.minX + horizontalMargin).rounded(),
                            y: (visible.minY + verticalMargin).rounded())
        let last = CGPoint(x: (visible.maxX - frame.width - horizontalMargin).rounded(),
                           y: (visible.maxY - frame.height - verticalMargin).rounded())
        guard grid.slot(for: CGRect(origin: first, size: frame.size)) == Slot(column: 0, row: 0),
              grid.slot(for: CGRect(origin: last, size: frame.size)) ==
                Slot(column: grid.columns - 1, row: grid.rows - 1) else {
            throw PiPError("This PiP window is too large for the selected move mode. Try resizing it.")
        }
        let x = first.x + (last.x - first.x) * CGFloat(next.column) / CGFloat(grid.columns - 1)
        let y = first.y + (last.y - first.y) * CGFloat(next.row) / CGFloat(grid.rows - 1)
        return Move(point: CGPoint(x: x.rounded(), y: y.rounded()), slot: next, grid: grid)
    }
}
