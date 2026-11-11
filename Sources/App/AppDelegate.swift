import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: RazonEngine?
    private var settings: SettingsWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        do {
            let engine = try RazonEngine(url: RazonEngine.configurationURL())
            self.engine = engine
            settings = try SettingsWindowController(engine: engine)
            installStatusItem()
            if try engine.configuration().general.show_settings_on_launch { showSettings(nil) }
        } catch {
            let alert = NSAlert()
            alert.messageText = "RazonHX could not start"
            alert.informativeText = "\(error.localizedDescription)\n\nYour existing configuration was not replaced. Move or repair config.json in ~/Library/Application Support/RazonHX, then reopen the app."
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
    private func installMenu() {
        let main = NSMenu()
        let root = NSMenuItem()
        let app = NSMenu(title: "RazonHX")
        app.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        app.addItem(NSMenuItem.separator())
        app.addItem(withTitle: "Quit RazonHX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        root.submenu = app
        main.addItem(root)
        let editRoot = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editRoot.submenu = edit
        main.addItem(editRoot)
        NSApp.mainMenu = main
    }
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = Bundle.main.url(forResource: "RazonHX", withExtension: "png", subdirectory: "Logo")
            .flatMap({ NSImage(contentsOf: $0) }) {
            image.size = NSSize(width: 20, height: 20)
            item.button?.image = image
        } else { item.button?.title = "RH" }
        item.button?.toolTip = "RazonHX — Redefine Your Desktop."
        let menu = NSMenu()
        menu.addItem(withTitle: "Open RazonHX Settings", action: #selector(showSettings(_:)), keyEquivalent: "").target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit RazonHX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
    @objc private func showSettings(_ sender: Any?) {
        settings?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(nil)
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { return false }
    func applicationWillTerminate(_ notification: Notification) {
        if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
        statusItem = nil
        settings = nil
        engine = nil
    }
}
