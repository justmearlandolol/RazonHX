import Foundation

struct RazonProfiles {
    let directory: URL

    var profiles: [URL] {
        let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        return (files ?? []).filter { $0.pathExtension == "json" }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    func save(_ config: RazonConfiguration, name: String) throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !cleaned.hasPrefix("."), cleaned.utf8.count <= 80,
            cleaned.rangeOfCharacter(from: CharacterSet(charactersIn: "/:\\").union(.controlCharacters)) == nil else {
            throw EngineError(message: "Choose a name of up to 80 bytes without slashes, colons, or leading dots.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let target = directory.appendingPathComponent(cleaned).appendingPathExtension("json")
        try Self.encoded(config).write(to: target, options: .withoutOverwriting)
    }

    static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    static func read(_ url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize, size <= 65_536 else {
            throw EngineError(message: "Choose a JSON file no larger than 64 KiB.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: 65_537)
        guard data.count <= 65_536 else { throw EngineError(message: "The JSON file exceeds 64 KiB.") }
        return data
    }
}
