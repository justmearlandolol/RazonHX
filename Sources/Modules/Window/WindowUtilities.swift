import AppKit
import ApplicationServices

final class WindowUtilities {
    enum Arrangement: String, CaseIterable {
        case left = "Left half", right = "Right half", fill = "Fill screen", center = "Center"
    }

    private var previous: NSRunningApplication?

    func remember(_ app: NSRunningApplication?) {
        if let app = app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            app.activationPolicy == .regular { previous = app }
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func arrange(_ action: Arrangement) throws {
        guard AXIsProcessTrusted() else {
            throw EngineError(message: "Allow RazonHX under System Settings → Privacy & Security → Accessibility, then try again.")
        }
        remember(NSWorkspace.shared.frontmostApplication)
        guard let app = previous, !app.isTerminated, let primary = NSScreen.screens.first else {
            throw EngineError(message: "Focus a window in another application first.")
        }
        let target = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(target, 1)
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target, kAXFocusedWindowAttribute as CFString, &result) == .success,
            let result = result, CFGetTypeID(result) == AXUIElementGetTypeID() else {
            throw EngineError(message: "\(app.localizedName ?? "The application") has no accessible focused window.")
        }
        let window = result as! AXUIElement
        AXUIElementSetMessagingTimeout(window, 1)
        var oldPosition = CGPoint.zero, oldSize = CGSize.zero
        guard read(window, kAXPositionAttribute, .cgPoint, &oldPosition),
            read(window, kAXSizeAttribute, .cgSize, &oldSize) else {
            throw EngineError(message: "This window does not report its position or size.")
        }
        let cocoa = NSRect(x: oldPosition.x, y: primary.frame.maxY - oldPosition.y - oldSize.height,
                          width: oldSize.width, height: oldSize.height)
        let screen = NSScreen.screens.max { a, b in
            let aa = a.frame.intersection(cocoa), bb = b.frame.intersection(cocoa)
            return aa.width * aa.height < bb.width * bb.height
        } ?? primary
        let area = screen.visibleFrame
        var width = area.width, height = area.height, x = area.minX, y = area.minY
        switch action {
        case .left: width = floor(width / 2)
        case .right: x += floor(width / 2); width = area.maxX - x
        case .center:
            width = min(width, oldSize.width); height = min(height, oldSize.height)
            x = area.midX - width / 2; y = area.midY - height / 2
        case .fill: break
        }
        var size = CGSize(width: width, height: height)
        var position = CGPoint(x: x, y: primary.frame.maxY - y - height)
        guard let location = AXValueCreate(.cgPoint, &position), let dimensions = AXValueCreate(.cgSize, &size) else { return }
        if size != oldSize,
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions) != .success {
            throw EngineError(message: "This window cannot be resized.")
        }
        guard AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, location) == .success else {
            if size != oldSize, let old = AXValueCreate(.cgSize, &oldSize) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, old)
            }
            throw EngineError(message: "This window cannot be moved.")
        }
    }

    private func read(_ element: AXUIElement, _ attribute: String, _ type: AXValueType, _ pointer: UnsafeMutableRawPointer) -> Bool {
        var item: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &item) == .success,
            let item = item, CFGetTypeID(item) == AXValueGetTypeID() else { return false }
        return AXValueGetValue(item as! AXValue, type, pointer)
    }
}
