import Foundation

struct RazonConfiguration: Codable {
    struct General: Codable {
        var show_settings_on_launch: Bool
        var hide_on_close: Bool
    }
    struct Appearance: Codable {
        var accent_color: String
        var background_color: String
        var text_color: String
        var window_opacity: Double
    }
    var schema_version: Int
    var general: General
    var appearance: Appearance
}

struct EngineError: LocalizedError {
    let message: String
    var errorDescription: String? { return message }
}

/// UI state changes only, never rendering frames. Handle and Rust strings have one owner.
final class RazonEngine {
    private var handle: OpaquePointer?
    static let didChange = Notification.Name("RazonHXConfigurationDidChange")

    static func configurationURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
        return base.appendingPathComponent("RazonHX", isDirectory: true).appendingPathComponent("config.json")
    }

    init(url: URL) throws {
        precondition(Thread.isMainThread)
        var error: UnsafeMutablePointer<CChar>?
        let status = url.path.withCString { rx_engine_create($0, &handle, &error) }
        try check(status, error)
    }
    deinit { rx_engine_destroy(handle) }

    private func check(_ status: Int32, _ error: UnsafeMutablePointer<CChar>?) throws {
        defer { rx_string_free(error) }
        if status != 0 {
            throw EngineError(message: error.map { String(cString: $0) } ?? "Unknown engine error.")
        }
    }
    func configuration() throws -> RazonConfiguration {
        precondition(Thread.isMainThread)
        var output: UnsafeMutablePointer<CChar>?
        var error: UnsafeMutablePointer<CChar>?
        let status = rx_engine_snapshot(handle, &output, &error)
        defer { rx_string_free(output) }
        try check(status, error)
        guard let value = output else { throw EngineError(message: "Missing engine snapshot.") }
        return try JSONDecoder().decode(RazonConfiguration.self, from: Data(String(cString: value).utf8))
    }
    func update(_ configuration: RazonConfiguration) throws {
        precondition(Thread.isMainThread)
        let data = try JSONEncoder().encode(configuration)
        guard let json = String(data: data, encoding: .utf8) else {
            throw EngineError(message: "Could not encode configuration.")
        }
        var error: UnsafeMutablePointer<CChar>?
        let status = json.withCString { rx_engine_update(handle, $0, &error) }
        try check(status, error)
        try notifyChanges()
    }
    func reset() throws {
        precondition(Thread.isMainThread)
        var error: UnsafeMutablePointer<CChar>?
        let status = rx_engine_reset(handle, &error)
        try check(status, error)
        try notifyChanges()
    }
    private func notifyChanges() throws {
        var changed = false
        while true {
            var output: UnsafeMutablePointer<CChar>?
            var error: UnsafeMutablePointer<CChar>?
            let status = rx_engine_next_event(handle, &output, &error)
            try check(status, error)
            guard let event = output else { break }
            changed = true
            rx_string_free(event)
        }
        if changed { NotificationCenter.default.post(name: RazonEngine.didChange, object: self) }
    }
}
