import AppKit

/// Native executable tests: no XCTest discovery or newer test-runtime dependency.
@main
struct FoundationTests {
    static func main() throws {
        precondition(Thread.isMainThread)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RazonHX-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("config.json")
        do {
            let engine = try RazonEngine(url: url)
            var configuration = try engine.configuration()
            assert(configuration.schema_version == 1)
            assert(configuration.appearance.accent_color == "#62F5D0")
            var notifications = 0
            let token = NotificationCenter.default.addObserver(forName: RazonEngine.didChange,
                object: engine, queue: nil) { _ in notifications += 1 }
            defer { NotificationCenter.default.removeObserver(token) }
            configuration.general.show_settings_on_launch = false
            try engine.update(configuration)
            assert(notifications == 1)
            try engine.update(configuration)
            assert(notifications == 1, "No-op updates should not notify")
            let reopened = try RazonEngine(url: url)
            let persisted = try reopened.configuration()
            assert(!persisted.general.show_settings_on_launch)
            configuration.appearance.accent_color = "invalid"
            do {
                try engine.update(configuration)
                fatalError("Invalid color was accepted")
            } catch { assert(error.localizedDescription.contains("#RRGGBB")) }
            let unchanged = try engine.configuration()
            assert(unchanged.appearance.accent_color == "#62F5D0")
            try engine.reset()
            let restored = try engine.configuration()
            assert(restored.general.show_settings_on_launch)
            assert(notifications == 2)
            print("PASS: Swift/C/Rust ownership, persistence, validation, reset and events")
        }
        let color = NSColor(razonHex: "#62F5D0")
        assert(color?.razonHex == "#62F5D0")
        assert(NSColor(razonHex: "#XYZXYZ") == nil)
        assert(NSColor(razonHex: "#FFF") == nil)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        try Data("broken".utf8).write(to: url)
        do {
            _ = try RazonEngine(url: url)
            fatalError("Corrupt configuration was accepted")
        } catch {
            let original = try String(contentsOf: url, encoding: .utf8)
            assert(original == "broken")
        }
        print("PASS: native color conversion and corrupt-file preservation")
    }
}
