import AppKit
import CoreGraphics

final class DesktopPanel: NSPanel {
    init(frame: NSRect, level: NSWindow.Level, interactive: Bool) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = interactive
        hidesOnDeactivate = false
        ignoresMouseEvents = !interactive
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        appearance = NSAppearance(named: .vibrantDark)
    }

    static let wallpaperLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
    static let widgetLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 2)
}

struct GlassPalette: Equatable {
    let accentHex: String
    let baseHex: String
    let textHex: String
    var accent: NSColor { return NSColor(razonHex: accentHex) ?? .cyan }
    var base: NSColor { return NSColor(razonHex: baseHex) ?? .black }
    var text: NSColor { return NSColor(razonHex: textHex) ?? .white }

    init(_ appearance: RazonConfiguration.Appearance) {
        accentHex = appearance.accent_color
        baseHex = appearance.background_color
        textHex = appearance.text_color
    }

    func surface(frame: NSRect, style: DesktopConfiguration.Surface) -> NSView {
        let wrap = NSView(frame: frame)
        wrap.wantsLayer = true
        wrap.layer?.cornerRadius = CGFloat(style.radius)
        wrap.layer?.masksToBounds = true
        if style.blur {
            let blur = NSVisualEffectView(frame: wrap.bounds)
            blur.material = .hudWindow
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.autoresizingMask = [.width, .height]
            wrap.addSubview(blur)
        }
        let tint = NSView(frame: wrap.bounds)
        tint.wantsLayer = true
        tint.layer?.cornerRadius = CGFloat(style.radius)
        tint.layer?.backgroundColor = base.withAlphaComponent(CGFloat(style.opacity)).cgColor
        tint.layer?.borderColor = accent.withAlphaComponent(0.57).cgColor
        tint.layer?.borderWidth = 1
        tint.autoresizingMask = [.width, .height]
        wrap.addSubview(tint)
        return wrap
    }
}

struct ScreenPlacement {
    static func panel(size: NSSize, edge: DesktopConfiguration.Edge, area: NSRect, margin: CGFloat = 8) -> NSRect {
        let x: CGFloat, y: CGFloat
        switch edge {
        case .top: x = area.midX - size.width / 2; y = area.maxY - size.height - margin
        case .bottom: x = area.midX - size.width / 2; y = area.minY + margin
        case .left: x = area.minX + margin; y = area.midY - size.height / 2
        case .right: x = area.maxX - size.width - margin; y = area.midY - size.height / 2
        }
        return NSRect(origin: NSPoint(x: x, y: y), size: size).integral
    }

    static func widget(size: NSSize, corner: DesktopConfiguration.Corner, area: NSRect) -> NSRect {
        let area = area.insetBy(dx: 20, dy: 20)
        let right = corner == .topRight || corner == .bottomRight
        let top = corner == .topLeft || corner == .topRight
        return NSRect(x: right ? area.maxX - size.width : area.minX,
                      y: top ? area.maxY - size.height : area.minY, width: size.width, height: size.height)
    }

    static func shouldReveal(at cursor: NSPoint, panel: NSRect, screen: NSRect, wasVisible: Bool) -> Bool {
        let range: CGFloat = wasVisible ? 32 : 15
        return screen.contains(cursor) && panel.insetBy(dx: -range, dy: -range).contains(cursor)
    }
}

final class OverlaySurface {
    let panels: [DesktopPanel]
    private let hitArea: NSRect
    private let screen: NSRect
    private let mode: DesktopConfiguration.Display
    private(set) var visible = false

    init(panels: [DesktopPanel], hitArea: NSRect, screen: NSRect, mode: DesktopConfiguration.Display) {
        self.panels = panels
        self.hitArea = hitArea
        self.screen = screen
        self.mode = mode
        update(at: NSEvent.mouseLocation)
    }

    func update(at cursor: NSPoint) {
        let show = mode == .always || (mode == .overlay && ScreenPlacement.shouldReveal(at: cursor,
            panel: hitArea, screen: screen, wasVisible: visible))
        guard show != visible else { return }
        visible = show
        if show { panels.forEach { $0.orderFrontRegardless() } }
        else { panels.forEach { $0.orderOut(nil) } }
    }

    deinit { panels.forEach { $0.close() } }
}

final class ControlAction: NSObject {
    let run: (Any) -> Void
    init(_ run: @escaping (Any) -> Void) { self.run = run }
    @objc func invoke(_ sender: Any) { run(sender) }
}
