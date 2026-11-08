import AppKit

private final class OverlayButton: NSButton {
    var geometry: TabGeometry?
    var tintBorder = false
    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        if let geometry {
            NSGraphicsContext.saveGraphicsState()
            geometry.silhouette().addClip()
            TabGeometry.tabFill(tinted: tintBorder).draw(in: bounds, angle: 90)
            NSGraphicsContext.restoreGraphicsState()
            NSColor(white: tintBorder ? 0.92 : 0.3, alpha: 0.85).setStroke()
            let perimeter = geometry.silhouette()
            perimeter.lineWidth = 1
            perimeter.stroke()
        }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let arrows = NSBezierPath()
        arrows.lineWidth = 1.7
        arrows.lineCapStyle = .round
        arrows.lineJoinStyle = .round
        let headLength: CGFloat = 3
        let headHalfWidth: CGFloat = 2.75
        let directions = [
            CGVector(dx: 1, dy: 0), CGVector(dx: -1, dy: 0),
            CGVector(dx: 0, dy: 1), CGVector(dx: 0, dy: -1)
        ]
        for direction in directions {
            let tip = CGPoint(x: center.x + 8 * direction.dx, y: center.y + 8 * direction.dy)
            let base = CGPoint(x: tip.x - headLength * direction.dx,
                               y: tip.y - headLength * direction.dy)
            arrows.move(to: center)
            arrows.line(to: tip)
            arrows.move(to: CGPoint(x: base.x - headHalfWidth * direction.dy,
                                    y: base.y + headHalfWidth * direction.dx))
            arrows.line(to: tip)
            arrows.line(to: CGPoint(x: base.x + headHalfWidth * direction.dy,
                                    y: base.y - headHalfWidth * direction.dx))
        }
        NSColor(white: tintBorder ? 0.16 : 1, alpha: isHighlighted ? 0.6 : 1).setStroke()
        arrows.stroke()
    }
}

struct TabGeometry {
    let video: CGRect
    let onTop: Bool
    let showsTab: Bool
    static let tabHeight: CGFloat = 36
    static let tabWidth: CGFloat = 104

    static func tabFill(tinted: Bool) -> NSGradient {
        NSGradient(starting: NSColor(white: tinted ? 0.82 : 0.04, alpha: 1),
                   ending: NSColor(white: tinted ? 0.94 : 0.12, alpha: 1))!
    }

    var tabFrame: CGRect {
        CGRect(x: video.midX - Self.tabWidth / 2,
               y: onTop ? video.maxY : video.minY - Self.tabHeight,
               width: Self.tabWidth, height: Self.tabHeight)
    }

    var frame: CGRect { showsTab ? video.union(tabFrame) : video }

    func silhouette() -> NSBezierPath {
        guard showsTab else { return NSBezierPath(rect: video) }
        let path = NSBezierPath()
        let center = video.midX
        let edge = video.maxY
        path.move(to: CGPoint(x: video.minX, y: video.minY))
        path.line(to: CGPoint(x: video.maxX, y: video.minY))
        path.line(to: CGPoint(x: video.maxX, y: edge))
        path.line(to: CGPoint(x: center + 52, y: edge))
        path.curve(to: CGPoint(x: center + 38, y: edge + 12),
                   controlPoint1: CGPoint(x: center + 42, y: edge),
                   controlPoint2: CGPoint(x: center + 38, y: edge + 4))
        path.line(to: CGPoint(x: center + 38, y: edge + 26))
        path.curve(to: CGPoint(x: center + 28, y: edge + 36),
                   controlPoint1: CGPoint(x: center + 38, y: edge + 32),
                   controlPoint2: CGPoint(x: center + 34, y: edge + 36))
        path.line(to: CGPoint(x: center - 28, y: edge + 36))
        path.curve(to: CGPoint(x: center - 38, y: edge + 26),
                   controlPoint1: CGPoint(x: center - 34, y: edge + 36),
                   controlPoint2: CGPoint(x: center - 38, y: edge + 32))
        path.line(to: CGPoint(x: center - 38, y: edge + 12))
        path.curve(to: CGPoint(x: center - 52, y: edge),
                   controlPoint1: CGPoint(x: center - 38, y: edge + 4),
                   controlPoint2: CGPoint(x: center - 42, y: edge))
        path.line(to: CGPoint(x: video.minX, y: edge))
        path.close()
        if !onTop {
            let flip = AffineTransform(m11: 1, m12: 0, m21: 0, m22: -1,
                                       tX: 0, tY: video.minY + video.maxY)
            path.transform(using: flip)
        }
        return path
    }
}

private final class OverlayOutline: NSView {
    var tintBorder = false {
        didSet { if oldValue != tintBorder { needsDisplay = true } }
    }
    var geometry: TabGeometry? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let geometry else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: geometry.video).addClip()
        let perimeter = geometry.silhouette()
        let band = perimeter.copy() as! NSBezierPath
        let interior = Placement.edgeBandInterior(of: geometry.video)
        if !interior.isEmpty { band.appendRect(interior) }
        band.windingRule = .evenOdd
        let opacity: CGFloat = tintBorder ? 0.7 : 0.9
        let gradient = NSGradient(
            starting: NSColor(white: 0.82, alpha: opacity),
            ending: NSColor(white: 0.94, alpha: opacity))
        if tintBorder {
            gradient?.draw(in: band, angle: 90)
        }
        NSColor(white: 0.92, alpha: 0.85).setStroke()
        perimeter.lineWidth = 1
        perimeter.stroke()
    }
}

final class Overlay {
    private let panel: NSPanel
    private let button: OverlayButton
    private let outlinePanel: NSPanel
    private let outlineView = OverlayOutline()
    private var hoverArea = CGRect.null
    private var hoverTimer: Timer?
    private var flashStart: TimeInterval?
    private var showsButton = false
    private var lastHoverTime: TimeInterval = 0

    init(target: AnyObject, action: Selector) {
        panel = Self.makePanel(size: CGSize(width: TabGeometry.tabWidth, height: TabGeometry.tabHeight))
        outlinePanel = Self.makePanel(size: .zero)
        button = OverlayButton(title: "", target: target, action: action)
        outlinePanel.ignoresMouseEvents = true
        outlinePanel.contentView = outlineView

        button.isBordered = false
        button.toolTip = "Move Picture-in-Picture"
        button.setAccessibilityLabel("Move Picture-in-Picture")
        panel.contentView = button
    }

    private static func makePanel(size: CGSize) -> NSPanel {
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.transient, .ignoresCycle]
        return panel
    }

    var isPointerOverButton: Bool {
        panel.isVisible && panel.frame.contains(NSEvent.mouseLocation)
    }

    var isFlashing: Bool { flashStart != nil }

    func track(_ window: PiPWindow, showButton: Bool, tintBorder: Bool) {
        guard let primary = NSScreen.screens.first,
              let screen = Placement.screen(for: window.frame, primaryTop: primary.frame.maxY) else {
            hide()
            return
        }
        let pip = Placement.appKitRect(window.frame, primaryTop: primary.frame.maxY)
        let display = screen.visibleFrame
        guard pip.intersects(display) else {
            hide()
            return
        }
        let onTop = pip.midY < display.midY
        let proposed = TabGeometry(video: pip, onTop: onTop, showsTab: showButton)
        showsButton = showButton && display.contains(proposed.tabFrame) && pip.width >= 116
        let geometry = TabGeometry(video: pip, onTop: onTop, showsTab: showsButton)
        let overlayFrame = geometry.frame.insetBy(dx: -1, dy: -1).intersection(display)
        let level = NSWindow.Level(rawValue: window.layer + 1)
        if panel.level != level { panel.level = level }
        if outlinePanel.level != level { outlinePanel.level = level }
        outlineView.geometry = TabGeometry(
            video: pip.offsetBy(dx: -overlayFrame.minX, dy: -overlayFrame.minY),
            onTop: onTop, showsTab: showsButton)
        outlineView.tintBorder = tintBorder
        button.geometry = TabGeometry(
            video: pip.offsetBy(dx: -geometry.tabFrame.minX, dy: -geometry.tabFrame.minY),
            onTop: onTop, showsTab: showsButton)
        button.tintBorder = tintBorder
        button.needsDisplay = true
        if outlinePanel.frame != overlayFrame { outlinePanel.setFrame(overlayFrame, display: true) }
        if panel.frame != geometry.tabFrame { panel.setFrame(geometry.tabFrame, display: true) }
        hoverArea = pip.intersection(display)

        if hoverTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                self?.updateVisibility()
            }
            hoverTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
        updateVisibility()
    }

    func flash() {
        guard hoverTimer != nil else { return }
        flashStart = ProcessInfo.processInfo.systemUptime
        updateVisibility()
    }

    static func flashAlpha(elapsed: TimeInterval) -> CGFloat {
        let wave = sin(.pi * elapsed / 0.6)
        return CGFloat(0.12 + 0.88 * wave * wave)
    }

    private func updateVisibility() {
        var alpha: CGFloat = 1
        if let flashStart {
            let elapsed = ProcessInfo.processInfo.systemUptime - flashStart
            if elapsed < 1.8 {
                alpha = Self.flashAlpha(elapsed: elapsed)
            } else {
                self.flashStart = nil
            }
        }
        let pointer = NSEvent.mouseLocation
        let now = ProcessInfo.processInfo.systemUptime
        if hoverArea.contains(pointer) || isPointerOverButton { lastHoverTime = now }
        let hovering = isFlashing || now - lastHoverTime < 0.25
        outlinePanel.alphaValue = alpha
        panel.alphaValue = alpha
        if hovering {
            let showingBand = !outlinePanel.isVisible
            if showingBand { outlinePanel.orderFrontRegardless() }
            if showsButton && (showingBand || !panel.isVisible) {
                panel.orderFrontRegardless()
            } else if !showsButton && panel.isVisible {
                panel.orderOut(nil)
            }
        } else {
            hidePanels()
        }
    }

    private func hidePanels() {
        panel.alphaValue = 0
        outlinePanel.alphaValue = 0
        if panel.isVisible { panel.orderOut(nil) }
        if outlinePanel.isVisible { outlinePanel.orderOut(nil) }
    }

    func hide() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        flashStart = nil
        lastHoverTime = 0
        hoverArea = .null
        hidePanels()
    }
}
