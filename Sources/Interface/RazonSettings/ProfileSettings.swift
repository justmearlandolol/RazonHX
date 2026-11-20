import AppKit

extension SettingsWindowController {
    func renderThemes() {
        let themes = card("Theme presets", subtitle: "Use Obsidian Violet for the violet glass and luminous outlines of the desktop reference, or customize any preset in Appearance.")
        for (name, palette) in RazonThemes.presets {
            command("Apply \(name)", in: themes) { controller in
                var updated = controller.config
                updated.appearance = palette
                controller.save(updated)
            }
        }
        let files = card("Theme files", subtitle: "Themes change colors and settings-window opacity without changing your desktop layout or wallpaper.")
        command("Export current theme…", in: files) { $0.export($0.config.appearance, name: "RazonHX-theme.json") }
        command("Import theme…", in: files) { controller in
            guard let url = controller.pickJSON() else { return }
            do {
                let theme = try JSONDecoder().decode(RazonConfiguration.Appearance.self, from: RazonProfiles.read(url))
                var updated = controller.config
                updated.appearance = theme
                controller.save(updated)
            } catch { controller.showError(error) }
        }
    }

    func renderProfiles() {
        let current = card("Desktop profiles", subtitle: "Save your colors, layout and module settings as a profile. Wallpaper assignments are restored when their files exist in this library. Media is not embedded in profile files.")
        command("Save current setup…", in: current) { controller in
            guard let name = controller.prompt("Save desktop profile", fields: [("Profile name", "My desktop")])?.first else { return }
            do { try controller.profiles.save(controller.config, name: name); controller.render() }
            catch { controller.showError(error) }
        }
        command("Export current profile…", in: current) { $0.export($0.config, name: "RazonHX-profile.json") }
        command("Import profile…", in: current) { controller in
            if let url = controller.pickJSON() { controller.applyProfile(url) }
        }
        let stored = profiles.profiles
        if !stored.isEmpty {
            let list = card("Saved on this Mac")
            for url in stored {
                let name = url.deletingPathExtension().lastPathComponent
                command("Switch to \(name)", in: list) { controller in controller.applyProfile(url) }
            }
        }
    }

    private func export<T: Encodable>(_ value: T, name: String) {
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["json"]
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try RazonProfiles.encoded(value).write(to: url, options: .atomic) }
        catch { showError(error) }
    }

    private func pickJSON() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["json"]
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func applyProfile(_ url: URL) {
        do {
            var updated = try JSONDecoder().decode(RazonConfiguration.self, from: RazonProfiles.read(url))
            guard updated.schema_version == config.schema_version else {
                throw EngineError(message: "This profile uses an unsupported configuration schema.")
            }
            let saved = updated.desktop.library
            var merged = config.desktop.library
            var ids = Set(merged.map(\.id))
            for item in saved where !ids.contains(item.id) {
                guard UUID(uuidString: item.id) != nil, (try? library.checkReadable(item)) != nil else { continue }
                ids.insert(item.id)
                merged.append(item)
            }
            updated.desktop.library = merged
            let usable = Set(merged.filter { !$0.archived && (try? library.checkReadable($0)) != nil }.map(\.id))
            updated.desktop.wallpapers = updated.desktop.wallpapers.filter { usable.contains($0.value) }
            let alert = NSAlert()
            alert.messageText = "Apply this desktop profile?"
            let weather = updated.desktop.weather.map { "\nWeather is enabled for \($0.name). Its coordinates will be sent to Open-Meteo when the clock is enabled." } ?? ""
            alert.informativeText = "This changes your desktop and app preferences. Your current wallpaper library is preserved.\(weather)"
            alert.addButton(withTitle: "Apply profile")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            save(updated)
        } catch { showError(error) }
    }
}
