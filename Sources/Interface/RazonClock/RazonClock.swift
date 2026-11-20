import AppKit

final class RazonClock: NSView {
    static let designSize = NSSize(width: 310, height: 310)
    private let config: DesktopConfiguration
    private let time = DateFormatter()
    private let day = DateFormatter()
    private let date = DateFormatter()
    private var timer: Timer?
    private var weatherTask: URLSessionDataTask?
    private var forecast: WeatherForecast?
    private var nextRefresh = Date.distantPast
    private var weatherFailed = false
    private var now = Date()

    override var isFlipped: Bool { return true }

    init(config: DesktopConfiguration) {
        self.config = config
        super.init(frame: NSRect(origin: .zero, size: Self.designSize))
        time.dateFormat = (config.twenty_four_hour ? "HH:mm" : "h:mm") + (config.seconds ? ":ss" : "")
            + (config.twenty_four_hour ? "" : " a")
        day.setLocalizedDateFormatFromTemplate("EEE")
        date.setLocalizedDateFormatFromTemplate("MMMMd")
        setAccessibilityLabel("RazonHX desktop clock and weather")
        tick()
        let timer = Timer(timeInterval: config.seconds ? 1 : 5, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func tick() {
        now = Date()
        if let weather = config.weather, now >= nextRefresh {
            nextRefresh = now.addingTimeInterval(900)
            weatherTask = WeatherForecast.fetch(weather) { [weak self] forecast in
                self?.forecast = forecast
                self?.weatherFailed = forecast == nil
                self?.needsDisplay = true
            }
        }
        needsDisplay = true
    }

    private func card(_ rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 28, yRadius: 28)
        NSGradient(starting: NSColor(white: 0.125, alpha: 0.97), ending: NSColor(white: 0.005, alpha: 0.98))?
            .draw(in: path, angle: 90)
        NSColor(white: 0.82, alpha: 0.18).setStroke()
        path.lineWidth = 0.7
        path.stroke()
    }

    private func write(_ string: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
                       weight: NSFont.Weight = .semibold, color: NSColor = .white, mono: Bool = false) {
        let font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        (string as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.scaleBy(x: bounds.width / Self.designSize.width, y: bounds.height / Self.designSize.height)
        let analog = NSRect(x: 1, y: 1, width: 146, height: 146)
        let digital = NSRect(x: 162, y: 1, width: 146, height: 146)
        let weather = NSRect(x: 1, y: 162, width: 307, height: 146)
        for frame in [analog, digital, weather] { card(frame) }
        dial(in: analog.insetBy(dx: 8, dy: 8))
        let dim = NSColor(white: 0.73, alpha: 1)
        write(time.string(from: now), 191, 29, config.twenty_four_hour ? 16 : 13, weight: .heavy, mono: true)
        write(day.string(from: now).uppercased(), 190, 55, 34, weight: .black)
        write(date.string(from: now), 192, 96, 13, weight: .bold, color: dim)
        drawWeather(dim: dim)
    }

    private func dial(in rect: NSRect) {
        let c = NSPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        let circle = NSBezierPath(ovalIn: rect)
        NSGradient(starting: NSColor(white: 0.025, alpha: 1), ending: NSColor(white: 0.4, alpha: 1))?.draw(in: circle, angle: 135)
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let elapsed = CGFloat(parts.minute ?? 0) + (config.seconds ? CGFloat(parts.second ?? 0) / 60 : 0)
        let hour = (CGFloat((parts.hour ?? 0) % 12) + elapsed / 60) * 30 - 90
        let minute = elapsed * 6 - 90
        func wedge(angle: CGFloat, arc: CGFloat, length: CGFloat, opacity: CGFloat) {
            for i in 0..<120 {
                let p = CGFloat(i) / 120
                let start = angle - arc + p * arc
                let path = NSBezierPath()
                path.move(to: c)
                path.appendArc(withCenter: c, radius: length, startAngle: start, endAngle: start + arc / 120 + 0.36)
                path.close()
                NSColor(white: 1, alpha: opacity * p * p * p).setFill()
                path.fill()
            }
        }
        wedge(angle: hour, arc: 143, length: radius * 0.72, opacity: 0.91)
        wedge(angle: minute, arc: 170, length: radius - 0.6, opacity: 0.98)
        NSColor(white: 0.91, alpha: 1).setStroke()
        circle.lineWidth = 1.1
        circle.stroke()
    }

    private func drawWeather(dim: NSColor) {
        let amber = NSColor(srgbRed: 1, green: 0.76, blue: 0.38, alpha: 1)
        write("⌖  \(String((config.weather?.name ?? "Local weather").prefix(15)))", 22, 184, 10, color: dim)
        write(time.string(from: now), 22, 270, 11, weight: .bold, color: dim, mono: true)
        guard let forecast = forecast else {
            write("—°", 24, 214, 30, weight: .black)
            write(config.weather == nil ? "Set a location in Clock & Date" : weatherFailed ? "Forecast unavailable" : "Loading forecast…",
                106, 228, 11, color: dim)
            return
        }
        write(weatherSymbol(forecast.current.weather_code), 23, 218, 19, weight: .bold, color: amber)
        write(String(format: "%.0f°", forecast.current.temperature_2m), 50, 213, 28, weight: .black)
        let values = forecast.nextHours
        guard values.count > 1 else { return }
        let minValue = values.map(\.temperature).min() ?? 0, maxValue = values.map(\.temperature).max() ?? 0
        let left: CGFloat = 123, right: CGFloat = 278, top: CGFloat = 206, span: CGFloat = 22
        let line = NSBezierPath()
        for (index, entry) in values.enumerated() {
            let x = left + (right - left) * CGFloat(index) / CGFloat(values.count - 1)
            let y = top + span * CGFloat((maxValue - entry.temperature) / max(1, maxValue - minValue))
            let grid = NSBezierPath()
            grid.move(to: NSPoint(x: x, y: 200)); grid.line(to: NSPoint(x: x, y: 235))
            NSColor(white: 1, alpha: 0.10).setStroke(); grid.lineWidth = 0.5; grid.stroke()
            if index == 0 { line.move(to: NSPoint(x: x, y: y)) } else { line.line(to: NSPoint(x: x, y: y)) }
            if index % 2 == 0 {
                write(weatherSymbol(entry.code), x - 4, 185, 9, color: index == 0 ? amber : dim)
                write(entry.time, x - 9, 241, 6.5, color: dim, mono: true)
            }
        }
        NSColor.white.setStroke(); line.lineWidth = 1.1; line.stroke()
        let chance = forecast.precipitation.map { "\($0)%" } ?? "—"
        for (index, metric) in [(chance, "Rain"), (String(format: "%.0f km/h", forecast.current.wind_speed_10m), "Wind"),
            ("\(forecast.current.relative_humidity_2m)%", "Humidity")].enumerated() {
            let x = 123 + CGFloat(index) * 58
            write(metric.0, x, 265, 10, weight: .bold)
            write(metric.1, x, 279, 7.5, color: dim)
        }
    }

    private func weatherSymbol(_ code: Int?) -> String {
        guard let code = code else { return "·" }
        switch code {
        case 0: return "☀"
        case 71...77, 85...86: return "❄"
        case 51...82: return "☂"
        case 95...99: return "ϟ"
        default: return "☁"
        }
    }

    deinit { timer?.invalidate(); weatherTask?.cancel() }
}
