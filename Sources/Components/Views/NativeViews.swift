import AppKit

extension NSColor {
    convenience init?(razonHex: String) {
        guard razonHex.count == 7, razonHex.first == "#",
              let rgb = UInt32(razonHex.dropFirst(), radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                  green: CGFloat((rgb >> 8) & 255) / 255,
                  blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
    var razonHex: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()),
                      Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool { return true }
}

final class CardView: NSStackView {
    init(color: NSColor) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 16
        edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        wantsLayer = true
        layer?.backgroundColor = color.withAlphaComponent(0.85).cgColor
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
