import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private enum Section: String, CaseIterable {
        case home = "Home", general = "General", appearance = "Appearance"
        case advanced = "Advanced", about = "About RazonHX"
    }
    private let engine: RazonEngine
    private var config: RazonConfiguration
    private var selected: Section = .home
    private let background = NSView()
    private let sidebar = NSStackView()
    private let content = NSStackView()
    private var observer: NSObjectProtocol?
    private var sectionButtons: [Section: NSButton] = [:]
    private var accent: NSColor { return NSColor(razonHex: config.appearance.accent_color) ?? .cyan }
    private var text: NSColor { return NSColor(razonHex: config.appearance.text_color) ?? .white }
    private var base: NSColor { return NSColor(razonHex: config.appearance.background_color) ?? .black }

    init(engine: RazonEngine) throws {
        self.engine = engine
        self.config = try engine.configuration()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "RazonHX"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 940, height: 700)
        window.appearance = NSAppearance(named: .vibrantDark)
        window.delegate = self
        window.center()
        buildLayout(window)
        observer = NotificationCenter.default.addObserver(forName: RazonEngine.didChange,
            object: engine, queue: .main) { [weak self] _ in self?.reload() }
        reload()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) } }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if config.general.hide_on_close { sender.orderOut(nil) } else { NSApp.terminate(nil) }
        return false
    }

    private func buildLayout(_ window: NSWindow) {
        let glass = NSVisualEffectView()
        glass.material = .sidebar
        glass.blendingMode = .behindWindow
        glass.state = .active
        window.contentView = glass
        background.translatesAutoresizingMaskIntoConstraints = false
        background.wantsLayer = true
        glass.addSubview(background)
        sidebar.orientation = .vertical
        sidebar.alignment = .leading
        sidebar.spacing = 5
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(sidebar)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(scroll)
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 20
        content.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(content)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            background.topAnchor.constraint(equalTo: glass.topAnchor),
            background.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            sidebar.topAnchor.constraint(equalTo: background.topAnchor, constant: 48),
            sidebar.widthAnchor.constraint(equalToConstant: 198),
            scroll.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 28),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -28),
            scroll.topAnchor.constraint(equalTo: background.topAnchor, constant: 56),
            scroll.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -24),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            content.topAnchor.constraint(equalTo: document.topAnchor),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
    }
    private func clear(_ stack: NSStackView) {
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
    }
    private func reload() {
        do { config = try engine.configuration() } catch { showError(error); return }
        window?.alphaValue = CGFloat(config.appearance.window_opacity)
        background.layer?.backgroundColor = base.withAlphaComponent(0.94).cgColor
        buildSidebar()
        render()
    }
    private func label(_ value: String, size: CGFloat = 13, bold: Bool = false, muted: Bool = false) -> NSTextField {
        let view = NSTextField(wrappingLabelWithString: value)
        view.font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        view.textColor = muted ? text.withAlphaComponent(0.58) : text
        view.isSelectable = true
        return view
    }
    private func add(_ view: NSView, to stack: NSStackView? = nil) {
        let stack = stack ?? content
        stack.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: stack.widthAnchor,
            constant: -(stack.edgeInsets.left + stack.edgeInsets.right)).isActive = true
    }
    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }
    private func buildSidebar() {
        clear(sidebar)
        sectionButtons.removeAll()
        add(label("RAZONHX", size: 23, bold: true), to: sidebar)
        add(label("Redefine Your Desktop.", size: 11, muted: true), to: sidebar)
        let sections: [(String, Section?)] = [
            ("Home", .home), ("General", .general), ("Appearance", .appearance),
            ("Desktop", nil), ("Wallpaper", nil), ("Toolbar", nil), ("Dock", nil),
            ("Clock & Date", nil), ("Launcher", nil), ("Window Manager", nil),
            ("Widgets", nil), ("Themes", nil), ("Profiles", nil), ("Modules", nil),
            ("Advanced", .advanced), ("About RazonHX", .about)
        ]
        for (name, section) in sections {
            if let section = section {
                let control = button(name, action: #selector(selectSection(_:)))
                control.isBordered = false
                control.alignment = .left
                control.font = NSFont.systemFont(ofSize: 12, weight: .medium)
                control.wantsLayer = true
                control.layer?.cornerRadius = 8
                control.layer?.backgroundColor = section == selected ? accent.withAlphaComponent(0.18).cgColor : NSColor.clear.cgColor
                control.attributedTitle = NSAttributedString(string: "  " + name, attributes: [
                    .foregroundColor: section == selected ? accent : text,
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium)
                ])
                control.heightAnchor.constraint(equalToConstant: 28).isActive = true
                sectionButtons[section] = control
                add(control, to: sidebar)
            } else {
                let planned = label("  " + name + "  ·  planned", size: 11, muted: true)
                planned.isSelectable = false
                planned.heightAnchor.constraint(equalToConstant: 21).isActive = true
                add(planned, to: sidebar)
            }
        }
        add(label("v0.1.0 · Foundation\nNative AppKit + Rust", size: 10, muted: true), to: sidebar)
    }
    @objc private func selectSection(_ sender: NSButton) {
        guard let section = sectionButtons.first(where: { $0.value === sender })?.key else { return }
        selected = section
        buildSidebar()
        render()
    }
    private func card(_ title: String, subtitle: String? = nil) -> CardView {
        let card = CardView(color: NSColor(razonHex: "#24282B")!)
        add(label(title, size: 15, bold: true), to: card)
        if let subtitle = subtitle { add(label(subtitle, muted: true), to: card) }
        add(card)
        return card
    }
    private func render() {
        clear(content)
        add(label(selected.rawValue, size: 30, bold: true))
        switch selected {
        case .home: renderHome()
        case .general: renderGeneral()
        case .appearance: renderAppearance()
        case .advanced: renderAdvanced()
        case .about: renderAbout()
        }
    }
    private func renderHome() {
        add(label("Your desktop, thoughtfully redefined.", size: 15, muted: true))
        let hero = card("A native foundation. A lighter footprint.",
            subtitle: "RazonHX combines AppKit with a small Rust core. This first increment establishes reliable settings and a safe bridge before adding desktop renderers.")
        if let url = Bundle.main.url(forResource: "RazonHX", withExtension: "png", subdirectory: "Logo"),
           let image = NSImage(contentsOf: url) {
            let view = NSImageView()
            view.image = image
            view.imageScaling = .scaleProportionallyUpOrDown
            view.heightAnchor.constraint(equalToConstant: 160).isActive = true
            add(view, to: hero)
        }
        add(button("Personalize appearance", action: #selector(openAppearance)), to: hero)
        let state = card("Engine connected")
        add(label("Configuration schema: \(config.schema_version)\nStorage: local JSON, atomically saved\nUpdates: event-driven; no background polling\nArchitecture: \(architecture)\nSystem: \(ProcessInfo.processInfo.operatingSystemVersionString)"), to: state)
        add(label("Wallpaper, overlays, launcher and widgets are planned—not active in this build. Memory targets have not yet been measured.", size: 12, muted: true))
    }
    private var architecture: String {
        #if arch(arm64)
        return "Apple Silicon · arm64"
        #else
        return "Intel · x86_64"
        #endif
    }
    @objc private func openAppearance() { selected = .appearance; buildSidebar(); render() }
    private func toggle(_ title: String, value: Bool, tag: Int, in card: CardView) {
        let control = NSButton(checkboxWithTitle: title, target: self, action: #selector(changeGeneral(_:)))
        control.state = value ? .on : .off
        control.tag = tag
        add(control, to: card)
    }
    private func renderGeneral() {
        add(label("Make RazonHX feel at home on your Mac.", muted: true))
        let startup = card("Application behavior")
        toggle("Show settings when RazonHX starts", value: config.general.show_settings_on_launch, tag: 0, in: startup)
        toggle("Keep running in the menu bar when the window closes", value: config.general.hide_on_close, tag: 1, in: startup)
        add(label("Use the RazonHX menu bar icon to reopen settings. If keep-running is disabled, closing settings quits the app. This does not register a login item.", size: 12, muted: true), to: startup)
        let storage = card("Your settings stay yours")
        add(label("Changes are validated and saved immediately. Invalid or newer configuration files are never silently replaced."), to: storage)
        add(button("Reveal configuration in Finder", action: #selector(revealConfiguration)), to: storage)
    }
    @objc private func changeGeneral(_ sender: NSButton) {
        var updated = config
        if sender.tag == 0 { updated.general.show_settings_on_launch = sender.state == .on }
        else { updated.general.hide_on_close = sender.state == .on }
        save(updated)
    }
    private func renderAppearance() {
        add(label("Mint accents. Dark glass. Entirely yours.", muted: true))
        let colors = card("Custom colors", subtitle: "These colors apply to RazonHX settings, not Apple's protected system interface.")
        for (index, entry) in [("Accent color", config.appearance.accent_color),
                               ("Background color", config.appearance.background_color),
                               ("Text color", config.appearance.text_color)].enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 12
            let name = label(entry.0)
            let value = label(entry.1, size: 12, muted: true)
            let well = NSColorWell()
            well.color = NSColor(razonHex: entry.1)!
            well.tag = index
            well.target = self
            well.action = #selector(changeColor(_:))
            well.widthAnchor.constraint(equalToConstant: 52).isActive = true
            well.heightAnchor.constraint(equalToConstant: 28).isActive = true
            row.addArrangedSubview(name)
            row.addArrangedSubview(value)
            row.addArrangedSubview(well)
            add(row, to: colors)
        }
        let transparency = card("Window opacity", subtitle: "Current: \(Int(config.appearance.window_opacity * 100))%. Range: 85–100%. Applies to this settings window.")
        let slider = NSSlider(value: config.appearance.window_opacity, minValue: 0.85, maxValue: 1,
            target: self, action: #selector(changeOpacity(_:)))
        slider.isContinuous = false
        slider.numberOfTickMarks = 4
        add(slider, to: transparency)
    }
    @objc private func changeColor(_ sender: NSColorWell) {
        guard let hex = sender.color.razonHex else { return }
        var updated = config
        switch sender.tag {
        case 0: updated.appearance.accent_color = hex
        case 1: updated.appearance.background_color = hex
        default: updated.appearance.text_color = hex
        }
        // Close the shared color panel before rebuilding its target control.
        sender.deactivate()
        NSColorPanel.shared.orderOut(nil)
        save(updated)
    }
    @objc private func changeOpacity(_ sender: NSSlider) {
        var updated = config
        updated.appearance.window_opacity = sender.doubleValue
        save(updated)
    }
    private func renderAdvanced() {
        add(label("Configuration and recovery tools.", muted: true))
        let storage = card("Configuration file")
        let path = (try? RazonEngine.configurationURL().path) ?? "Unavailable"
        add(label(path, size: 12, muted: true), to: storage)
        add(button("Reveal in Finder", action: #selector(revealConfiguration)), to: storage)
        let reset = card("Reset settings", subtitle: "Restore bundled defaults. Your existing configuration is backed up first; desktop and media files are not touched.")
        add(button("Restore defaults…", action: #selector(resetSettings)), to: reset)
        let compatibility = card("Compatibility")
        add(label("Intel: macOS 10.13 or later\nApple Silicon: macOS 11.0 or later\n\nHigh Sierra cannot run on Apple Silicon. Build success on a modern runner is not proof of High Sierra runtime compatibility. Real-hardware validation is pending.", size: 12, muted: true), to: compatibility)
    }
    private func renderAbout() {
        let info = card("RazonHX", subtitle: "Redefine Your Desktop.")
        add(label("Version 0.1.0 · Foundation\nNative macOS desktop customization environment\nSwift 5 · AppKit · Rust · C ABI\n\nOfficial mint/cyan crowned-star artwork supplied by the project owner. Visual layout is inspired by the supplied Seelen UI reference, with independent implementation."), to: info)
        let scope = card("Development status")
        add(label("Implemented: native application lifecycle, persistent validated configuration, event notifications, appearance settings, recovery tools and dual-architecture build automation.\n\nNot yet implemented: wallpaper playback, desktop panels, launcher, window management, widgets, themes and profiles.", muted: true), to: scope)
    }
    @objc private func revealConfiguration() {
        do { NSWorkspace.shared.activateFileViewerSelecting([try RazonEngine.configurationURL()]) }
        catch { showError(error) }
    }
    @objc private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = "Restore RazonHX defaults?"
        alert.informativeText = "A backup will be saved beside config.json before resetting your settings."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Restore defaults")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            let url = try RazonEngine.configurationURL()
            let backup = url.deletingLastPathComponent().appendingPathComponent("config-backup-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: url, to: backup)
            try engine.reset()
        } catch { showError(error) }
    }
    private func save(_ updated: RazonConfiguration) {
        do { try engine.update(updated) }
        catch { showError(error); reload() }
    }
    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "RazonHX couldn't complete this change"
        alert.runModal()
    }
}
