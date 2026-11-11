import AppKit

/// Exercises real AppKit targets/actions against the Rust-backed settings window.
@main
struct SettingsSmokeTests {
    static func descendants(_ view: NSView) -> [NSView] {
        return [view] + view.subviews.flatMap { descendants($0) }
    }
    static func findButton(_ title: String, in root: NSView) -> NSButton {
        guard let button = descendants(root).compactMap({ $0 as? NSButton }).first(where: {
            $0.title.trimmingCharacters(in: .whitespaces) == title
        }) else { fatalError("Missing functional control: \(title)") }
        return button
    }
    static func main() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RazonHX-ui-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let engine = try RazonEngine(url: root.appendingPathComponent("config.json"))
        let controller = try SettingsWindowController(engine: engine)
        guard let window = controller.window, let content = window.contentView else {
            fatalError("Native settings window was not constructed")
        }
        content.layoutSubtreeIfNeeded()
        assert(window.minSize.width == 940)
        findButton("General", in: content).performClick(nil)
        findButton("Show settings when RazonHX starts", in: content).performClick(nil)
        let general = try engine.configuration()
        assert(!general.general.show_settings_on_launch)

        findButton("Appearance", in: content).performClick(nil)
        guard let well = descendants(content).compactMap({ $0 as? NSColorWell }).first(where: { $0.tag == 0 }),
              let colorAction = well.action else { fatalError("Missing accent color control") }
        well.color = NSColor(razonHex: "#AABBCC")!
        assert(application.sendAction(colorAction, to: well.target, from: well))
        let colors = try engine.configuration()
        assert(colors.appearance.accent_color == "#AABBCC")
        guard let slider = descendants(content).compactMap({ $0 as? NSSlider }).first,
              let opacityAction = slider.action else { fatalError("Missing opacity control") }
        slider.doubleValue = 0.95
        assert(application.sendAction(opacityAction, to: slider.target, from: slider))
        let appearance = try engine.configuration()
        assert(abs(appearance.appearance.window_opacity - 0.95) < 0.001)
        assert(abs(Double(window.alphaValue) - 0.95) < 0.001)

        for section in ["Home", "Advanced", "About RazonHX", "Appearance"] {
            findButton(section, in: content).performClick(nil)
            content.layoutSubtreeIfNeeded()
        }
        assert(!controller.windowShouldClose(window), "Keep-running mode should order out rather than destroy the window")
        let reopened = try RazonEngine(url: root.appendingPathComponent("config.json"))
        let persisted = try reopened.configuration()
        assert(persisted.appearance.accent_color == "#AABBCC")
        assert(!persisted.general.show_settings_on_launch)
        print("PASS: AppKit construction, sidebar navigation, real control actions, window appearance and persistence")
        withExtendedLifetime(controller) {}
    }
}
