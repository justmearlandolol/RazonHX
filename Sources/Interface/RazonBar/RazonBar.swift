import AppKit

final class RazonBar {
    let surface: OverlaySurface
    private let application = NSTextField(labelWithString: "")
    private let clock = NSTextField(labelWithString: "")
    private let power = NSTextField(labelWithString: "")
    private let date = DateFormatter()
    private var actions: [ControlAction] = []
    private var timer: Timer?

    init(screen: NSScreen, config: DesktopConfiguration, palette: GlassPalette,
         settings: @escaping () -> Void, launcher: @escaping () -> Void) {
        let style = config.toolbar
        let area = screen.visibleFrame
        let frame = ScreenPlacement.panel(size: NSSize(width: max(1, area.width - 24), height: CGFloat(style.size)),
            edge: style.edge, area: area, margin: 6)
        let side = min(176, (frame.width - 12) / 3)
        let middle = min(config.seconds ? 224 : 203, (frame.width - 12) / 3)
        let left = NSRect(x: frame.minX, y: frame.minY, width: side, height: frame.height)
        let center = NSRect(x: frame.midX - middle / 2, y: frame.minY, width: middle, height: frame.height)
        let right = NSRect(x: frame.maxX - side, y: frame.minY, width: side, height: frame.height)
        let panels = [left, center, right].map { rect -> DesktopPanel in
            let panel = DesktopPanel(frame: rect, level: .floating, interactive: true)
            panel.contentView = palette.surface(frame: NSRect(origin: .zero, size: rect.size), style: style)
            return panel
        }
        surface = OverlaySurface(panels: panels, hitArea: frame, screen: screen.frame, mode: style.display)
        date.setLocalizedDateFormatFromTemplate(config.twenty_four_hour ? (config.seconds ? "EEEdMMMHHmmss" : "EEEdMMMHHmm")
            : (config.seconds ? "EEEdMMMhmmssa" : "EEEdMMMhmm a"))
        func install(_ label: NSTextField, panel: DesktopPanel, width: CGFloat, x: CGFloat, align: NSTextAlignment) {
            guard let view = panel.contentView else { return }
            label.textColor = palette.text
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
            label.alignment = align
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSRect(x: x, y: (view.bounds.height - 16) / 2, width: max(0, width), height: 16)
            view.addSubview(label)
        }
        func button(_ title: String, tip: String, panel: DesktopPanel, x: CGFloat, run: @escaping () -> Void) {
            guard let view = panel.contentView else { return }
            let action = ControlAction { _ in run() }
            actions.append(action)
            let control = NSButton(title: title, target: action, action: #selector(ControlAction.invoke(_:)))
            control.isBordered = false
            control.toolTip = tip
            control.setAccessibilityLabel(tip)
            control.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: palette.accent,
                .font: NSFont.systemFont(ofSize: 16, weight: .semibold)])
            control.frame = NSRect(x: x, y: 0, width: 34, height: view.bounds.height)
            view.addSubview(control)
        }
        button("▦", tip: "Open application launcher", panel: panels[0], x: 2, run: launcher)
        install(application, panel: panels[0], width: side - 42, x: 36, align: .left)
        install(clock, panel: panels[1], width: middle - 8, x: 4, align: .center)
        install(power, panel: panels[2], width: side - 43, x: 6, align: .right)
        button("≡", tip: "Open RazonHX settings", panel: panels[2], x: side - 36, run: settings)
        refreshApplication()
        refresh()
        let timer = Timer(timeInterval: config.seconds ? 1 : 5, repeats: true) { [weak self] _ in
            if self?.surface.visible == true { self?.refresh() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshApplication() {
        application.stringValue = NSWorkspace.shared.frontmostApplication?.localizedName ?? "RazonHX"
        application.toolTip = application.stringValue
    }

    func refresh() {
        clock.stringValue = date.string(from: Date())
        let network = SystemWidgets.network
        power.stringValue = "\(network != nil ? "◉" : "○")   \(SystemWidgets.battery ?? "AC")"
        power.toolTip = network.map { "Network interface: \($0)" } ?? "No primary network interface"
    }

    deinit { timer?.invalidate() }
}
