import AppKit

final class RazonLauncher: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private struct App {
        let url: URL
        let name: String
        let id: String
    }
    private var window: NSPanel?
    private let search = NSSearchField()
    private let table = NSTableView()
    private var apps: [App] = []
    private var matches: [App] = []
    private var palette: GlassPalette?
    private let recentKey = "RazonHX.RecentApplicationIDs"

    func show(palette: GlassPalette) {
        self.palette = palette
        if window == nil { build() }
        window?.backgroundColor = palette.base
        if window?.isVisible == true { window?.makeKeyAndOrderFront(nil); return }
        search.stringValue = ""
        scan()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(search)
    }

    private func build() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 488, height: 364),
            styleMask: [.titled, .closable, .utilityWindow, .fullSizeContentView], backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.acceptsMouseMovedEvents = true
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.appearance = NSAppearance(named: .vibrantDark)
        guard let content = panel.contentView else { return }
        search.frame = NSRect(x: 18, y: 304, width: 452, height: 28)
        search.placeholderString = "Search installed apps"
        search.delegate = self
        content.addSubview(search)
        let scroll = NSScrollView(frame: NSRect(x: 18, y: 16, width: 452, height: 278))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Application"))
        column.width = scroll.bounds.width - 12
        table.addTableColumn(column)
        table.rowHeight = 36
        table.headerView = nil
        table.backgroundColor = .clear
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(openSelection)
        scroll.documentView = table
        content.addSubview(scroll)
        window = panel
    }

    private func scan() {
        let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let directories = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices"), home]
        var unique = Set<String>()
        var found: [App] = []
        for root in directories {
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
            for case let url as URL in files {
                guard url.pathExtension.lowercased() == "app" else { continue }
                files.skipDescendants()
                guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                    unique.insert(id).inserted else { continue }
                if root.path == "/System/Library/CoreServices", id != "com.apple.finder" { continue }
                found.append(App(url: url, name: FileManager.default.displayName(atPath: url.path), id: id))
            }
        }
        apps = found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        filter()
    }

    private func filter() {
        let query = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            let recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
            matches = recent.compactMap { id in apps.first { $0.id == id } } + apps.filter { !recent.contains($0.id) }
        } else { matches = apps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) } }
        table.reloadData()
        if !matches.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            table.scrollRowToVisible(0)
        }
    }

    func controlTextDidChange(_ obj: Notification) { filter() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)): openSelection(); return true
        case #selector(NSResponder.cancelOperation(_:)): window?.orderOut(nil); return true
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveUp(_:)):
            guard !matches.isEmpty else { return true }
            let next = max(0, min(matches.count - 1, table.selectedRow + (selector == #selector(NSResponder.moveDown(_:)) ? 1 : -1)))
            table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
            table.scrollRowToVisible(next)
            return true
        default: return false
        }
    }

    @objc private func openSelection() {
        guard matches.indices.contains(table.selectedRow) else { return }
        let app = matches[table.selectedRow]
        guard NSWorkspace.shared.open(app.url) else { NSSound.beep(); return }
        var recent = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
        recent.removeAll { $0 == app.id }
        recent.insert(app.id, at: 0)
        UserDefaults.standard.set(Array(recent.prefix(12)), forKey: recentKey)
        window?.orderOut(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { return matches.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard matches.indices.contains(row) else { return nil }
        let app = matches[row]
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 438, height: 36))
        let icon = NSImageView(frame: NSRect(x: 6, y: 6, width: 24, height: 24))
        icon.image = NSWorkspace.shared.icon(forFile: app.url.path)
        let name = NSTextField(labelWithString: app.name)
        name.textColor = palette?.text ?? .labelColor
        name.frame = NSRect(x: 40, y: 9, width: 390, height: 18)
        view.addSubview(icon)
        view.addSubview(name)
        return view
    }
}
