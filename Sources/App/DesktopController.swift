import AppKit
import CoreGraphics

extension NSScreen {
    var razonDisplayID: String {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return "all" }
        let id = number.uint32Value
        if let uuid = rx_display_copy_uuid(id) { return uuid as String }
        return String(id)
    }
}

final class DesktopController {
    private struct MediaWindow {
        let panel: DesktopPanel
        let renderer: WallpaperRenderer
        let item: DesktopConfiguration.Wallpaper
    }

    let library: WallpaperLibrary
    let profiles: RazonProfiles
    let windows = WindowUtilities()
    private let engine: RazonEngine
    private let settings: () -> Void
    private let launcher = RazonLauncher()
    private var config: RazonConfiguration?
    private var bars: [RazonBar] = []
    private var docks: [RazonDock] = []
    private var widgets: [DesktopPanel] = []
    private var media: [String: MediaWindow] = [:]
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var localMotion: Any?
    private var globalMotion: Any?
    private var screensAsleep = false
    private var sessionInactive = false

    init(engine: RazonEngine, directory: URL, settings: @escaping () -> Void) {
        self.engine = engine
        self.settings = settings
        library = WallpaperLibrary(directory: directory.appendingPathComponent("WallpaperLibrary", isDirectory: true))
        profiles = RazonProfiles(directory: directory.appendingPathComponent("Profiles", isDirectory: true))
        let workspace = NSWorkspace.shared.notificationCenter
        observe(RazonEngine.didChange, object: engine) { [weak self] _ in self?.reload() }
        observe(NSApplication.didChangeScreenParametersNotification) { [weak self] _ in self?.reload(force: true) }
        observe(NSWorkspace.activeSpaceDidChangeNotification, center: workspace) { [weak self] _ in self?.reload(force: true) }
        observe(NSWorkspace.didActivateApplicationNotification, center: workspace) { [weak self] notification in
            self?.windows.remember(notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
            self?.bars.forEach { $0.refreshApplication() }
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observe(name, center: workspace) { [weak self] _ in self?.docks.forEach { $0.refresh() } }
        }
        observe(NSWorkspace.screensDidSleepNotification, center: workspace) { [weak self] _ in
            self?.screensAsleep = true; self?.applyPlayback()
        }
        observe(NSWorkspace.screensDidWakeNotification, center: workspace) { [weak self] _ in
            self?.screensAsleep = false; self?.applyPlayback()
        }
        observe(NSWorkspace.sessionDidResignActiveNotification, center: workspace) { [weak self] _ in
            self?.sessionInactive = true; self?.applyPlayback()
        }
        observe(NSWorkspace.sessionDidBecomeActiveNotification, center: workspace) { [weak self] _ in
            self?.sessionInactive = false; self?.applyPlayback()
        }
        windows.remember(NSWorkspace.shared.frontmostApplication)
        reload(force: true)
    }

    private func observe(_ name: Notification.Name, center: NotificationCenter = .default, object: Any? = nil,
                         _ action: @escaping (Notification) -> Void) {
        let token = center.addObserver(forName: name, object: object, queue: .main, using: action)
        observers.append((center, token))
    }

    func showLauncher() {
        guard let config = config else { return }
        launcher.show(palette: GlassPalette(config.appearance))
    }

    private func reload(force: Bool = false) {
        guard let next = try? engine.configuration() else { return }
        let previous = config
        let old = previous?.desktop, new = next.desktop
        config = next
        let palette = GlassPalette(next.appearance)
        let oldPalette = previous.map { GlassPalette($0.appearance) }
        let recolor = oldPalette != palette
        let screens = NSScreen.screens
        let openLauncher: () -> Void = { [weak self] in self?.showLauncher() }
        if force || recolor || old?.toolbar != new.toolbar || old?.seconds != new.seconds || old?.twenty_four_hour != new.twenty_four_hour {
            bars = new.toolbar.display == .hidden ? [] : screens.map {
                RazonBar(screen: $0, config: new, palette: palette, settings: settings, launcher: openLauncher)
            }
        }
        if force || recolor || old?.dock != new.dock || old?.dock_apps != new.dock_apps || old?.toolbar != new.toolbar {
            docks = new.dock.display == .hidden ? [] : screens.map { RazonDock(screen: $0, config: new, palette: palette, launcher: openLauncher) }
        }
        if force || recolor || old?.clock != new.clock || old?.clock_corner != new.clock_corner || old?.seconds != new.seconds
            || old?.twenty_four_hour != new.twenty_four_hour || old?.weather != new.weather || old?.widgets != new.widgets
            || old?.toolbar != new.toolbar || old?.dock != new.dock {
            widgets.forEach { $0.close() }
            widgets.removeAll()
            if let screen = screens.first { makeWidgets(on: screen, config: new, palette: palette) }
        }
        updateMedia(on: screens, config: new, palette: palette, rebuild: old?.scaling != new.scaling || (force && previous == nil),
            recolor: oldPalette?.accentHex != palette.accentHex)
        configureMotion(enabled: new.toolbar.display == .overlay || new.dock.display == .overlay)
    }

    private func makeWidgets(on screen: NSScreen, config: DesktopConfiguration, palette: GlassPalette) {
        var area = screen.visibleFrame
        func inset(_ edge: DesktopConfiguration.Edge, _ amount: CGFloat) {
            switch edge {
            case .top: area.size.height -= amount
            case .bottom: area.origin.y += amount; area.size.height -= amount
            case .left: area.origin.x += amount; area.size.width -= amount
            case .right: area.size.width -= amount
            }
        }
        if config.toolbar.display != .hidden { inset(config.toolbar.edge, CGFloat(config.toolbar.size + 6)) }
        if config.dock.display != .hidden { inset(config.dock.edge, CGFloat(config.dock.size + 26)) }
        func put(_ view: NSView, corner: DesktopConfiguration.Corner) {
            let size = view.frame.size
            guard area.width >= size.width + 40, area.height >= size.height + 40 else { return }
            let frame = ScreenPlacement.widget(size: size, corner: corner, area: area)
            let panel = DesktopPanel(frame: frame, level: DesktopPanel.widgetLevel, interactive: false)
            panel.contentView = view
            panel.orderFrontRegardless()
            widgets.append(panel)
        }
        if config.clock { put(RazonClock(config: config), corner: config.clock_corner) }
        if config.widgets {
            let top = config.clock_corner == .topLeft || config.clock_corner == .topRight
            let corner: DesktopConfiguration.Corner = top ? .bottomRight : .topRight
            put(SystemWidgetView(palette: palette), corner: corner)
        }
    }

    private func updateMedia(on screens: [NSScreen], config: DesktopConfiguration, palette: GlassPalette,
                             rebuild: Bool, recolor: Bool) {
        let validDisplays = Set(screens.map(\.razonDisplayID))
        for key in Array(media.keys) where !validDisplays.contains(key) { removeMedia(key) }
        for screen in screens {
            let key = screen.razonDisplayID
            let selected = config.wallpapers[key] ?? config.wallpapers["all"]
            guard let item = config.library.first(where: { $0.id == selected && !$0.archived }) else {
                removeMedia(key); continue
            }
            if let current = media[key], item.id == current.item.id, !rebuild, !(recolor && item.kind == .wav) {
                if current.panel.frame != screen.frame { current.panel.setFrame(screen.frame, display: true) }
                continue
            }
            removeMedia(key)
            do {
                let render = try WallpaperRenderer(url: library.url(for: item), kind: item.kind, scaling: config.scaling,
                    accent: palette.accent, active: false, volume: 0)
                let panel = DesktopPanel(frame: screen.frame, level: DesktopPanel.wallpaperLevel, interactive: false)
                panel.contentView = render
                panel.orderFrontRegardless()
                media[key] = MediaWindow(panel: panel, renderer: render, item: item)
            } catch { NSLog("RazonHX wallpaper %@ could not be loaded: %@", item.name, error.localizedDescription) }
        }
        applyPlayback()
    }

    private func removeMedia(_ id: String) { media.removeValue(forKey: id)?.panel.close() }

    private func applyPlayback() {
        guard let config = config?.desktop else { return }
        let audible = NSScreen.screens.map(\.razonDisplayID).first { id in
            guard let item = media[id]?.item else { return false }
            return item.kind == .mp4 || item.kind == .wav
        }
        for (id, instance) in media {
            instance.renderer.setPlayback(active: !screensAsleep && !sessionInactive && !config.media_paused,
                volume: id == audible ? config.media_volume : 0)
        }
    }

    private func configureMotion(enabled: Bool) {
        if enabled, localMotion == nil {
            let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            localMotion = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in self?.moved(); return event }
            globalMotion = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in self?.moved() }
        } else if !enabled { removeMotion() }
    }

    private func moved() {
        let at = NSEvent.mouseLocation
        for bar in bars {
            let wasVisible = bar.surface.visible
            bar.surface.update(at: at)
            if !wasVisible && bar.surface.visible { bar.refresh() }
        }
        docks.forEach { $0.surface.update(at: at) }
    }

    private func removeMotion() {
        if let monitor = localMotion { NSEvent.removeMonitor(monitor); localMotion = nil }
        if let monitor = globalMotion { NSEvent.removeMonitor(monitor); globalMotion = nil }
    }

    deinit {
        removeMotion()
        observers.forEach { $0.0.removeObserver($0.1) }
        media.values.forEach { $0.panel.close() }
        widgets.forEach { $0.close() }
    }
}
