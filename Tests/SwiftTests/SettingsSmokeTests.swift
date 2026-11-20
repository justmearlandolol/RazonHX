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
        let controller = try SettingsWindowController(engine: engine, directory: root)
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

        for section in ["Toolbar", "Dock"] {
            findButton(section, in: content).performClick(nil)
            guard let display = descendants(content).compactMap({ $0 as? NSPopUpButton }).first(where: {
                $0.itemTitles.contains("On overlay")
            }), let action = display.action else { fatalError("Missing On overlay control for \(section)") }
            display.selectItem(withTitle: "On overlay")
            assert(application.sendAction(action, to: display.target, from: display))
        }
        let desktop = try engine.configuration().desktop
        assert(desktop.toolbar.display == .overlay && desktop.dock.display == .overlay)
        let screen = NSRect(x: -600, y: 0, width: 600, height: 400)
        let panel = ScreenPlacement.panel(size: NSSize(width: 200, height: 50), edge: .bottom, area: screen)
        let near = NSPoint(x: panel.midX, y: panel.maxY + 12)
        let leaving = NSPoint(x: panel.midX, y: panel.maxY + 24)
        assert(ScreenPlacement.shouldReveal(at: near, panel: panel, screen: screen, wasVisible: false))
        assert(!ScreenPlacement.shouldReveal(at: leaving, panel: panel, screen: screen, wasVisible: false))
        assert(ScreenPlacement.shouldReveal(at: leaving, panel: panel, screen: screen, wasVisible: true))
        assert(!ScreenPlacement.shouldReveal(at: NSPoint(x: panel.midX, y: -5), panel: panel, screen: screen, wasVisible: true))

        for section in ["Home", "Desktop", "Wallpaper", "Clock & Date", "Launcher", "Window Manager", "Widgets",
                        "Themes", "Profiles", "Modules", "Advanced", "About RazonHX", "Appearance"] {
            findButton(section, in: content).performClick(nil)
            content.layoutSubtreeIfNeeded()
        }
        let png = root.appendingPathComponent("test.png")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<2 { for x in 0..<2 { bitmap.setColor(.white, atX: x, y: y) } }
        try bitmap.representation(using: .png, properties: [:])!.write(to: png)
        let imported = try controller.library.add(png, name: "Test image", category: "Tests")
        let managed = controller.library.url(for: imported)
        assert(managed != png)
        try FileManager.default.removeItem(at: png)
        try controller.library.checkReadable(imported)
        let preview = try WallpaperRenderer(url: managed, kind: imported.kind, scaling: .fill,
            accent: .cyan, active: false, volume: 0)
        preview.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        preview.layoutSubtreeIfNeeded()
        assert(preview.subviews.compactMap { $0 as? NSImageView }.first?.image != nil)

        assert(!controller.windowShouldClose(window), "Keep-running mode should order out rather than destroy the window")
        let reopened = try RazonEngine(url: root.appendingPathComponent("config.json"))
        let persisted = try reopened.configuration()
        assert(persisted.appearance.accent_color == "#AABBCC")
        assert(!persisted.general.show_settings_on_launch)
        print("PASS: AppKit construction, sidebar navigation, real control actions, window appearance and persistence")
        withExtendedLifetime(controller) {}
    }
}
