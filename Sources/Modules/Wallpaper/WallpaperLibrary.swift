import AppKit
import AVFoundation
import ImageIO

final class WallpaperLibrary {
    static let extensions = DesktopConfiguration.Media.allCases.map(\.rawValue) + ["htm"]
    let directory: URL

    init(directory: URL) { self.directory = directory }

    func url(for item: DesktopConfiguration.Wallpaper) -> URL {
        return directory.appendingPathComponent(item.id).appendingPathExtension(item.kind.rawValue)
    }

    func add(_ source: URL, name: String, category: String) throws -> DesktopConfiguration.Wallpaper {
        let ext = source.pathExtension.lowercased()
        guard source.isFileURL, let kind = DesktopConfiguration.Media(rawValue: ext == "htm" ? "html" : ext) else {
            throw EngineError(message: "Choose a local PNG, GIF, MP4, HTML, or WAV file.")
        }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        let limit = kind == .html ? 2_000_000 : kind == .wav || kind == .gif ? 50_000_000 : 500_000_000
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize,
            size > 0, size <= limit else {
            throw EngineError(message: "Choose a regular file no larger than \(limit / 1_000_000) MB.")
        }
        let item = DesktopConfiguration.Wallpaper(id: UUID().uuidString, name: name, kind: kind,
            category: category, favorite: false, archived: false)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let destination = url(for: item)
        try FileManager.default.copyItem(at: source, to: destination)
        do { try validate(destination, kind: kind) }
        catch { try? FileManager.default.removeItem(at: destination); throw error }
        return item
    }

    func checkReadable(_ item: DesktopConfiguration.Wallpaper) throws {
        let values = try url(for: item).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw EngineError(message: "This wallpaper file is missing or is not a regular file.")
        }
    }

    private func validate(_ url: URL, kind: DesktopConfiguration.Media) throws {
        let invalid = EngineError(message: "This file could not be decoded as \(kind.rawValue.uppercased()).")
        switch kind {
        case .png, .gif:
            let uti = kind == .png ? "public.png" : "com.compuserve.gif"
            guard let image = CGImageSourceCreateWithURL(url as CFURL, nil),
                let type = CGImageSourceGetType(image), type as String == uti,
                CGImageSourceGetCount(image) > 0,
                let props = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [String: Any],
                let w = props[kCGImagePropertyPixelWidth as String] as? Int,
                let h = props[kCGImagePropertyPixelHeight as String] as? Int,
                w > 0, h > 0, w <= 8192, h <= 8192, w * h <= 24_000_000,
                kind != .gif || (w * h <= 4_000_000 && CGImageSourceGetCount(image) <= 500),
                CGImageSourceCreateThumbnailAtIndex(image, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 64
                ] as CFDictionary) != nil else { throw invalid }
        case .mp4:
            let asset = AVURLAsset(url: url)
            guard asset.isPlayable, !asset.tracks(withMediaType: .video).isEmpty,
                asset.duration.seconds.isFinite, asset.duration.seconds > 0 else { throw invalid }
        case .html:
            let html = try String(contentsOf: url, encoding: .utf8)
            guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw invalid }
        case .wav:
            let audio = try AVAudioFile(forReading: url)
            let handle = try FileHandle(forReadingFrom: url)
            defer { handle.closeFile() }
            let header = handle.readData(ofLength: 12)
            guard header.count == 12, Data(header.prefix(4)) == Data("RIFF".utf8),
                Data(header.suffix(4)) == Data("WAVE".utf8), audio.length > 0 else { throw invalid }
        }
    }
}

final class WallpaperDropView: NSTextField {
    var onDrop: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return file(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = file(from: sender) else { return false }
        onDrop?(url)
        return true
    }

    private func file(from sender: NSDraggingInfo) -> URL? {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL]
        guard let url = urls?.first, WallpaperLibrary.extensions.contains(url.pathExtension.lowercased()) else { return nil }
        return url
    }
}
