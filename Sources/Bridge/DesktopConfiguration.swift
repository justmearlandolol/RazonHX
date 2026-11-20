import Foundation

struct DesktopConfiguration: Codable, Equatable {
    enum Display: String, Codable, CaseIterable {
        case always, overlay, hidden
        var title: String {
            switch self {
            case .always: return "Always visible"
            case .overlay: return "On overlay"
            case .hidden: return "Hidden"
            }
        }
    }

    enum Edge: String, Codable, CaseIterable { case top, bottom, left, right }
    enum Corner: String, Codable, CaseIterable {
        case topLeft = "top_left", topRight = "top_right", bottomLeft = "bottom_left", bottomRight = "bottom_right"
    }
    enum Scaling: String, Codable, CaseIterable { case fill, fit, stretch, center }
    enum Media: String, Codable, CaseIterable { case png, gif, mp4, html, wav }

    struct Surface: Codable, Equatable {
        var display: Display
        var edge: Edge
        var opacity: Double
        var blur: Bool
        var size: Int
        var radius: Int
    }

    struct Wallpaper: Codable, Equatable {
        var id: String
        var name: String
        var kind: Media
        var category: String
        var favorite: Bool
        var archived: Bool
    }

    struct Weather: Codable, Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    var toolbar: Surface
    var dock: Surface
    var clock: Bool
    var clock_corner: Corner
    var twenty_four_hour: Bool
    var seconds: Bool
    var widgets: Bool
    var dock_apps: [String]
    var library: [Wallpaper]
    var wallpapers: [String: String]
    var scaling: Scaling
    var media_paused: Bool
    var media_volume: Double
    var weather: Weather?
}
