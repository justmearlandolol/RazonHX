import Foundation

enum RazonThemes {
    static let presets: [(String, RazonConfiguration.Appearance)] = [
        ("Obsidian Violet", .init(accent_color: "#CE79E8", background_color: "#130E1B", text_color: "#F8EDFF", window_opacity: 1)),
        ("Razon Mint", .init(accent_color: "#62F5D0", background_color: "#17191B", text_color: "#E8F5F2", window_opacity: 1)),
        ("Glacier Blue", .init(accent_color: "#81C5FF", background_color: "#101927", text_color: "#EDF6FF", window_opacity: 1))
    ]
}
