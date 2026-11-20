import AppKit

extension SettingsWindowController {
    func renderWallpaper() {
        let panel = card("Wallpaper library", subtitle: "PNG, GIF, MP4, local HTML, and WAV. Imports are copied to RazonHX so moving the original file does not break the wallpaper.")
        let drop = WallpaperDropView(frame: .zero)
        drop.stringValue = "Drop a wallpaper here, or import from Finder"
        drop.alignment = .center
        drop.textColor = accent
        drop.isEditable = false
        drop.isSelectable = false
        drop.isBordered = false
        drop.drawsBackground = false
        drop.wantsLayer = true
        drop.layer?.cornerRadius = 10
        drop.layer?.borderColor = accent.withAlphaComponent(0.35).cgColor
        drop.layer?.borderWidth = 1
        drop.heightAnchor.constraint(equalToConstant: 28).isActive = true
        drop.registerForDraggedTypes([.fileURL])
        drop.onDrop = { [weak self] url in self?.importWallpaper(url) }
        add(drop, to: panel)
        command("Import wallpaper…", in: panel) { controller in
            let picker = NSOpenPanel()
            picker.allowedFileTypes = WallpaperLibrary.extensions
            guard picker.runModal() == .OK, let url = picker.url else { return }
            controller.importWallpaper(url)
        }
        let titles = ["All wallpapers", "Favorites", "Archived"] + Set(config.desktop.library.filter { !$0.archived }.map(\.category)).sorted()
        if !titles.indices.contains(wallpaperFilter) { wallpaperFilter = 0 }
        choices("Library filter", titles, index: wallpaperFilter, in: panel) { controller, index in
            controller.wallpaperFilter = index
            controller.render()
        }
        let entries = config.desktop.library.filter { item in
            switch wallpaperFilter {
            case 0: return !item.archived
            case 1: return !item.archived && item.favorite
            case 2: return item.archived
            default: return !item.archived && item.category == titles[wallpaperFilter]
            }
        }
        if let first = entries.first {
            let index = entries.firstIndex { $0.id == selectedWallpaper } ?? 0
            let item = entries.indices.contains(index) ? entries[index] : first
            selectedWallpaper = item.id
            choices("Wallpaper", entries.map { "\($0.favorite ? "★ " : "")\($0.name) · \($0.kind.rawValue.uppercased())" },
                    index: index, in: panel) { controller, index in
                controller.selectedWallpaper = entries[index].id
                controller.render()
            }
            renderWallpaperActions(item, entries: entries)
        } else {
            add(label("No wallpapers in this view.", muted: true), to: panel)
        }
        renderPlaybackSettings()
    }

    private func renderWallpaperActions(_ item: DesktopConfiguration.Wallpaper, entries: [DesktopConfiguration.Wallpaper]) {
        let selection = card(item.name, subtitle: "\(item.kind.rawValue.uppercased()) · \(item.category)")
        if item.archived {
            command("Restore to library", in: selection) { controller in
                controller.wallpaperFilter = 0
                controller.editWallpaper(item.id) { $0.archived = false }
            }
            return
        }
        let ids = ["all"] + NSScreen.screens.map(\.razonDisplayID)
        let displayTitles = ["All displays"] + NSScreen.screens.enumerated().map { index, screen in
            "Display \(index + 1) · \(Int(screen.frame.width)) × \(Int(screen.frame.height))"
        }
        if !ids.contains(selectedDisplay) { selectedDisplay = "all" }
        choices("Apply to", displayTitles, index: ids.firstIndex(of: selectedDisplay) ?? 0, in: selection) { controller, index in
            controller.selectedDisplay = ids[index]
            controller.render()
        }
        command("Preview wallpaper…", in: selection) { $0.previewWallpaper(item) }
        let inherited = config.desktop.wallpapers[selectedDisplay] ?? config.desktop.wallpapers["all"]
        if config.desktop.wallpapers[selectedDisplay] == item.id {
            add(label("Active for this selection", size: 12, bold: true), to: selection)
        } else if let inherited = inherited, let active = config.desktop.library.first(where: { $0.id == inherited }) {
            add(label("Current: \(active.name)", size: 12, muted: true), to: selection)
        }
        command("Apply wallpaper", in: selection) { controller in controller.apply(item) }
        if entries.count > 1 {
            command("Apply next in this view", in: selection) { controller in
                let active = controller.config.desktop.wallpapers[controller.selectedDisplay] ?? controller.config.desktop.wallpapers["all"]
                let index = entries.firstIndex { $0.id == active } ?? -1
                let next = entries[(index + 1) % entries.count]
                controller.selectedWallpaper = next.id
                controller.apply(next)
            }
        }
        if config.desktop.wallpapers[selectedDisplay] != nil {
            command(selectedDisplay == "all" ? "Remove wallpaper from all displays" : "Remove this display override", in: selection) { controller in
                let target = controller.selectedDisplay
                controller.changeDesktop {
                    if target == "all" { $0.wallpapers.removeAll() }
                    else { $0.wallpapers.removeValue(forKey: target) }
                }
            }
        }
        command(item.favorite ? "Remove from favorites" : "Add to favorites", in: selection) {
            $0.editWallpaper(item.id) { $0.favorite.toggle() }
        }
        command("Edit name and category…", in: selection) { controller in
            guard let values = controller.prompt("Edit wallpaper", fields: [("Name", item.name), ("Category", item.category)]) else { return }
            controller.wallpaperFilter = 0
            controller.editWallpaper(item.id) { $0.name = values[0]; $0.category = values[1] }
        }
        command("Archive wallpaper", in: selection) { controller in
            controller.changeDesktop { desktop in
                guard let index = desktop.library.firstIndex(where: { $0.id == item.id }) else { return }
                desktop.library[index].archived = true
                desktop.wallpapers = desktop.wallpapers.filter { $0.value != item.id }
            }
        }
    }

    private func renderPlaybackSettings() {
        let playback = card("Playback", subtitle: "Audio is muted by default. WAV files are drawn as an animated waveform. HTML supports UTF-8, inline styles and CSS animations; scripts and external assets are blocked.")
        let options = DesktopConfiguration.Scaling.allCases
        choices("Image scaling", options.map { $0.rawValue.capitalized }, index: options.firstIndex(of: config.desktop.scaling) ?? 0, in: playback) { controller, index in
            controller.changeDesktop { $0.scaling = options[index] }
        }
        checkbox("Pause animated wallpaper playback", config.desktop.media_paused, in: playback) { controller, value in
            controller.changeDesktop { $0.media_paused = value }
        }
        range("Wallpaper volume · \(Int((config.desktop.media_volume * 100).rounded()))%", value: config.desktop.media_volume,
            limits: 0...1, in: playback) { controller, value in controller.changeDesktop { $0.media_volume = value } }
    }

    private func apply(_ item: DesktopConfiguration.Wallpaper) {
        let display = selectedDisplay
        do { try library.checkReadable(item) }
        catch { showError(error); return }
        changeDesktop {
            if display == "all" { $0.wallpapers.removeAll() }
            $0.wallpapers[display] = item.id
        }
    }

    private func editWallpaper(_ id: String, _ edit: (inout DesktopConfiguration.Wallpaper) -> Void) {
        changeDesktop { desktop in
            if let index = desktop.library.firstIndex(where: { $0.id == id }) { edit(&desktop.library[index]) }
        }
    }

    private func importWallpaper(_ url: URL) {
        guard config.desktop.library.count < 100 else {
            showError(EngineError(message: "This library already contains 100 wallpapers.")); return
        }
        let proposed = String(url.deletingPathExtension().lastPathComponent.prefix(38))
        guard let fields = prompt("Import wallpaper", fields: [("Name", proposed), ("Category", "Uncategorized")]) else { return }
        let store = library
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let item = try store.add(url, name: fields[0], category: fields[1])
                DispatchQueue.main.async {
                    guard let self = self else { try? FileManager.default.removeItem(at: store.url(for: item)); return }
                    self.selectedWallpaper = item.id
                    self.wallpaperFilter = 0
                    var updated = self.config
                    updated.desktop.library.append(item)
                    if !self.save(updated) { try? FileManager.default.removeItem(at: store.url(for: item)) }
                }
            } catch {
                DispatchQueue.main.async { self?.showError(error) }
            }
        }
    }

    private func previewWallpaper(_ item: DesktopConfiguration.Wallpaper) {
        do {
            let preview = try WallpaperRenderer(url: library.url(for: item), kind: item.kind, scaling: config.desktop.scaling,
                accent: accent, active: true, volume: 0)
            preview.frame = NSRect(x: 0, y: 0, width: 460, height: 258)
            let alert = NSAlert()
            alert.messageText = item.name
            alert.informativeText = "Wallpaper preview · audio muted"
            alert.accessoryView = preview
            alert.addButton(withTitle: "Close preview")
            alert.runModal()
            preview.setPlayback(active: false, volume: 0)
        } catch { showError(error) }
    }
}
