import AppKit

final class RazonDock {
    let surface: OverlaySurface
    private var actions: [ControlAction] = []
    private var dots: [String: NSView] = [:]

    init(screen: NSScreen, config: DesktopConfiguration, palette: GlassPalette, launcher: @escaping () -> Void) {
        let style = config.dock
        let vertical = style.edge == .left || style.edge == .right
        let area = screen.visibleFrame
        let spacing: CGFloat = 6, padding: CGFloat = 8
        let apps = config.dock_apps.compactMap { id -> (String, URL)? in
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { (id, $0) }
        }
        let available = (vertical ? area.height : area.width) - 44
        let limit = (available - 2 * padding - spacing * CGFloat(apps.count)) / CGFloat(apps.count + 1)
        let cell = max(16, min(CGFloat(style.size), limit))
        let length = (cell + spacing) * CGFloat(apps.count) + cell + padding * 2
        let thickness = cell + padding * 2
        let size = vertical ? NSSize(width: thickness, height: length) : NSSize(width: length, height: thickness)
        let sharedEdge = config.toolbar.display != .hidden && config.toolbar.edge == style.edge
        let margin = CGFloat(10 + (sharedEdge ? config.toolbar.size + 6 : 0))
        let frame = ScreenPlacement.panel(size: size, edge: style.edge, area: area, margin: margin)
        let panel = DesktopPanel(frame: frame, level: .floating, interactive: true)
        let root = palette.surface(frame: NSRect(origin: .zero, size: frame.size), style: style)
        panel.contentView = root
        surface = OverlaySurface(panels: [panel], hitArea: frame, screen: screen.frame, mode: style.display)
        func tile(_ title: String, image: NSImage?, index: Int, run: @escaping () -> Void) -> NSRect {
            let offset = padding + CGFloat(index) * (cell + spacing)
            let box = NSRect(x: vertical ? padding : offset, y: vertical ? length - offset - cell : padding,
                width: cell, height: cell)
            let tile = NSView(frame: box)
            tile.wantsLayer = true
            tile.layer?.cornerRadius = min(10, CGFloat(style.radius))
            tile.layer?.backgroundColor = palette.accent.withAlphaComponent(0.12).cgColor
            tile.layer?.borderColor = palette.accent.withAlphaComponent(0.20).cgColor
            tile.layer?.borderWidth = 1
            let action = ControlAction { _ in run() }
            actions.append(action)
            let button = NSButton(title: image == nil ? "▦" : "", target: action, action: #selector(ControlAction.invoke(_:)))
            button.isBordered = false
            button.image = image
            button.imageScaling = .scaleProportionallyUpOrDown
            button.imagePosition = image == nil ? .noImage : .imageOnly
            button.toolTip = title
            button.setAccessibilityLabel(title)
            if image == nil {
                button.attributedTitle = NSAttributedString(string: "▦", attributes: [.foregroundColor: palette.text,
                    .font: NSFont.systemFont(ofSize: cell * 0.52, weight: .semibold)])
            }
            button.frame = tile.bounds.insetBy(dx: 4, dy: 4)
            tile.addSubview(button)
            root.addSubview(tile)
            return box
        }
        for (index, entry) in apps.enumerated() {
            let (id, url) = entry
            let name = FileManager.default.displayName(atPath: url.path)
            let box = tile(name, image: NSWorkspace.shared.icon(forFile: url.path), index: index) {
                NSWorkspace.shared.open(url)
            }
            let x = vertical ? box.minX - 5 : box.midX - 1.5
            let y = vertical ? box.midY - 1.5 : box.minY - 5
            let dot = NSView(frame: NSRect(x: x, y: y, width: 3, height: 3))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = palette.text.cgColor
            dot.layer?.cornerRadius = 1.5
            root.addSubview(dot)
            dots[id] = dot
        }
        _ = tile("Open application launcher", image: nil, index: apps.count, run: launcher)
        refresh()
    }

    func refresh() {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        for (id, dot) in dots { dot.isHidden = !running.contains(id) }
    }
}
