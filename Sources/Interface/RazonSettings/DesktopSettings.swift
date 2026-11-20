import AppKit

extension SettingsWindowController {
    func changeDesktop(_ change: (inout DesktopConfiguration) -> Void) {
        var updated = config
        change(&updated.desktop)
        save(updated)
    }

    func command(_ title: String, in card: CardView, _ run: @escaping (SettingsWindowController) -> Void) {
        let action = ControlAction { [weak self] _ in if let self = self { run(self) } }
        controlActions.append(action)
        let control = NSButton(title: title, target: action, action: #selector(ControlAction.invoke(_:)))
        control.bezelStyle = .rounded
        add(control, to: card)
    }

    func checkbox(_ title: String, _ value: Bool, in card: CardView,
                  _ run: @escaping (SettingsWindowController, Bool) -> Void) {
        let action = ControlAction { [weak self] sender in
            if let self = self, let button = sender as? NSButton { run(self, button.state == .on) }
        }
        controlActions.append(action)
        let control = NSButton(checkboxWithTitle: title, target: action, action: #selector(ControlAction.invoke(_:)))
        control.state = value ? .on : .off
        add(control, to: card)
    }

    func choices(_ title: String, _ items: [String], index: Int, in card: CardView,
                 _ run: @escaping (SettingsWindowController, Int) -> Void) {
        guard !items.isEmpty else { return }
        let action = ControlAction { [weak self] sender in
            if let self = self, let popup = sender as? NSPopUpButton,
                items.indices.contains(popup.indexOfSelectedItem) { run(self, popup.indexOfSelectedItem) }
        }
        controlActions.append(action)
        let control = NSPopUpButton(frame: .zero, pullsDown: false)
        control.addItems(withTitles: items)
        control.selectItem(at: index)
        control.target = action
        control.action = #selector(ControlAction.invoke(_:))
        control.setAccessibilityLabel(title)
        add(label(title, size: 12, bold: true), to: card)
        add(control, to: card)
    }

    func range(_ title: String, value: Double, limits: ClosedRange<Double>, in card: CardView,
               _ run: @escaping (SettingsWindowController, Double) -> Void) {
        let action = ControlAction { [weak self] sender in
            if let self = self, let slider = sender as? NSSlider { run(self, slider.doubleValue) }
        }
        controlActions.append(action)
        let control = NSSlider(value: value, minValue: limits.lowerBound, maxValue: limits.upperBound,
            target: action, action: #selector(ControlAction.invoke(_:)))
        control.isContinuous = false
        control.setAccessibilityLabel(title)
        add(label(title, size: 12, bold: true), to: card)
        add(control, to: card)
    }

    func renderDesktop() {
        let card = self.card("Desktop modules", subtitle: "Changes apply immediately and are restored the next time RazonHX opens.")
        renderDisplay(\.toolbar, title: "Toolbar display", in: card)
        renderDisplay(\.dock, title: "Dock display", in: card)
        checkbox("Show desktop clock", config.desktop.clock, in: card) { controller, value in controller.changeDesktop { $0.clock = value } }
        checkbox("Show system status widget", config.desktop.widgets, in: card) { controller, value in controller.changeDesktop { $0.widgets = value } }
    }

    private func renderDisplay(_ key: WritableKeyPath<DesktopConfiguration, DesktopConfiguration.Surface>, title: String, in card: CardView) {
        let modes = DesktopConfiguration.Display.allCases
        choices(title, modes.map(\.title), index: modes.firstIndex(of: config.desktop[keyPath: key].display) ?? 0, in: card) { controller, index in
            controller.changeDesktop { $0[keyPath: key].display = modes[index] }
        }
    }

    func renderSurface(_ key: WritableKeyPath<DesktopConfiguration, DesktopConfiguration.Surface>, title: String,
                       edges: [DesktopConfiguration.Edge]) {
        let style = config.desktop[keyPath: key]
        let display = card("Visibility and position", subtitle: "On overlay hides the \(title.lowercased()) until the pointer comes near it. Move the pointer away to hide it again.")
        renderDisplay(key, title: "\(title) display", in: display)
        choices("Position", edges.map { $0.rawValue.capitalized }, index: edges.firstIndex(of: style.edge) ?? 0, in: display) { controller, index in
            controller.changeDesktop { $0[keyPath: key].edge = edges[index] }
        }
        let glass = card("Glass and geometry")
        checkbox("Blur background", style.blur, in: glass) { controller, value in controller.changeDesktop { $0[keyPath: key].blur = value } }
        range("Surface opacity · \(Int((style.opacity * 100).rounded()))%", value: style.opacity, limits: 0.2...1, in: glass) { controller, value in
            controller.changeDesktop { $0[keyPath: key].opacity = value }
        }
        range("Size · \(style.size) pt", value: Double(style.size), limits: 28...64, in: glass) { controller, value in
            controller.changeDesktop { $0[keyPath: key].size = Int(value.rounded()) }
        }
        range("Corner radius · \(style.radius) pt", value: Double(style.radius), limits: 0...32, in: glass) { controller, value in
            controller.changeDesktop { $0[keyPath: key].radius = Int(value.rounded()) }
        }
    }

    func renderDockApps() {
        let pinned = card("Favorite applications", subtitle: "Running favorites show a small dot below their icons. Up to 12 apps can be pinned.")
        command("Pin an application…", in: pinned) { controller in
            let panel = NSOpenPanel()
            panel.allowedFileTypes = ["app"]
            panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
            guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
            guard !controller.config.desktop.dock_apps.contains(id) else { return }
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil else {
                controller.showError(EngineError(message: "Open this app once in Finder to register it with macOS, then pin it again.")); return
            }
            controller.changeDesktop { $0.dock_apps.append(id) }
        }
        for id in config.desktop.dock_apps {
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id).map { FileManager.default.displayName(atPath: $0.path) } ?? id
            command("Unpin \(name)", in: pinned) { controller in controller.changeDesktop { $0.dock_apps.removeAll { $0 == id } } }
        }
    }

    func renderClock() {
        let clock = card("Monochrome desktop clock", subtitle: "Analog sweep, digital time, and a weather card. The standalone widget appears on your primary display.")
        checkbox("Show desktop clock", config.desktop.clock, in: clock) { controller, value in controller.changeDesktop { $0.clock = value } }
        checkbox("Use 24-hour time", config.desktop.twenty_four_hour, in: clock) { controller, value in controller.changeDesktop { $0.twenty_four_hour = value } }
        checkbox("Show seconds", config.desktop.seconds, in: clock) { controller, value in controller.changeDesktop { $0.seconds = value } }
        let corners = DesktopConfiguration.Corner.allCases
        choices("Desktop corner", corners.map { $0.rawValue.replacingOccurrences(of: "_", with: " ").capitalized },
                index: corners.firstIndex(of: config.desktop.clock_corner) ?? 0, in: clock) { controller, index in
            controller.changeDesktop { $0.clock_corner = corners[index] }
        }
        let weather = card("Local weather", subtitle: "Optional. With the clock enabled, the coordinates you enter are sent to Open-Meteo to retrieve the forecast. Device location is never requested.")
        if let location = config.desktop.weather {
            add(label(location.name, bold: true), to: weather)
            command("Disable weather", in: weather) { $0.changeDesktop { $0.weather = nil } }
        }
        command("Set weather location…", in: weather) { controller in
            let old = controller.config.desktop.weather
            guard let fields = controller.prompt("Set weather location", fields: [
                ("Display name", old?.name ?? ""), ("Latitude", old.map { String($0.latitude) } ?? ""),
                ("Longitude", old.map { String($0.longitude) } ?? "")]) else { return }
            guard let latitude = Double(fields[1]), let longitude = Double(fields[2]) else {
                controller.showError(EngineError(message: "Enter coordinates in decimal degrees, for example −6.2 and 106.8.")); return
            }
            controller.changeDesktop { $0.weather = .init(name: fields[0], latitude: latitude, longitude: longitude) }
        }
    }

    func renderWidgets() {
        let card = self.card("System status", subtitle: "CPU activity, active/wired/compressed memory, the primary network interface and battery state.")
        checkbox("Show system status widget", config.desktop.widgets, in: card) { controller, value in controller.changeDesktop { $0.widgets = value } }
    }

    func renderLauncher() {
        let card = self.card("Search installed applications", subtitle: "Open from the toolbar or dock, or press ⌘⇧L while RazonHX is active. Use ↑ and ↓ to select, Return to launch, or Escape to close.")
        command("Open RazonLauncher", in: card) { $0.desktop?.showLauncher() }
    }

    func renderWindowManager() {
        let card = self.card("Arrange the last focused window", subtitle: "Focus a window in another app, then return here and choose its placement. Accessibility permission is required; some windows cannot be resized.")
        command("Request Accessibility permission", in: card) { _ in WindowUtilities.requestPermission() }
        for arrangement in WindowUtilities.Arrangement.allCases {
            command(arrangement.rawValue, in: card) { controller in
                do { try controller.desktop?.windows.arrange(arrangement) }
                catch { controller.showError(error) }
            }
        }
    }

    func prompt(_ title: String, fields: [(String, String)]) -> [String]? {
        let alert = NSAlert()
        alert.messageText = title
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 310, height: CGFloat(56 * fields.count)))
        let inputs = fields.enumerated().map { index, entry -> NSTextField in
            let y = CGFloat((fields.count - 1 - index) * 56)
            let label = NSTextField(labelWithString: entry.0)
            label.frame = NSRect(x: 0, y: y + 26, width: 310, height: 20)
            view.addSubview(label)
            let input = NSTextField(string: entry.1)
            input.frame = NSRect(x: 0, y: y, width: 310, height: 24)
            view.addSubview(input)
            return input
        }
        for (index, input) in inputs.enumerated() where index + 1 < inputs.count { input.nextKeyView = inputs[index + 1] }
        alert.accessoryView = view
        alert.window.initialFirstResponder = inputs.first
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return inputs.map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
