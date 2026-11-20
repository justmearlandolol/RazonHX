import AppKit
import IOKit.ps
import SystemConfiguration
import Darwin

struct SystemWidgets {
    private var priorCPU: [UInt32]?

    static var battery: String? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [AnyObject] else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                let total = info[kIOPSMaxCapacityKey] as? Int, total > 0 else { continue }
            let charging = info[kIOPSIsChargingKey] as? Bool == true
            return "\(charging ? "ϟ " : "")\(Int((100 * Double(capacity) / Double(total)).rounded()))%"
        }
        return nil
    }

    static var network: String? {
        for family in ["IPv4", "IPv6"] {
            let key = "State:/Network/Global/\(family)" as CFString
            if let value = SCDynamicStoreCopyValue(nil, key) as? [String: Any],
                let name = value["PrimaryInterface"] as? String { return name }
        }
        return nil
    }

    mutating func load() -> Int? {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var stats = host_cpu_load_info_data_t()
        let count = MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        var elements = mach_msg_type_number_t(count)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: count) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &elements)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let ticks = stats.cpu_ticks
        let current = [ticks.0, ticks.1, ticks.2, ticks.3]
        defer { priorCPU = current }
        guard let prior = priorCPU else { return nil }
        let delta = zip(current, prior).map { Double($0.0 &- $0.1) }
        let total = delta.reduce(0, +)
        return total > 0 ? Int((100 * (1 - delta[Int(CPU_STATE_IDLE)] / total)).rounded()) : nil
    }

    static var memory: String {
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        var info = vm_statistics64_data_t()
        let count = MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.size
        var elements = mach_msg_type_number_t(count)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: count) {
                host_statistics64(host, HOST_VM_INFO64, $0, &elements)
            }
        }
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        guard result == KERN_SUCCESS else { return String(format: "%.1f GB installed", total) }
        let pages = Double(info.active_count) + Double(info.wire_count) + Double(info.compressor_page_count)
        let used = pages * Double(getpagesize()) / 1_073_741_824
        return String(format: "%.1f / %.1f GB", used, total)
    }
}

final class SystemWidgetView: NSView {
    private let field = NSTextField(wrappingLabelWithString: "")
    private var stats = SystemWidgets()
    private var timer: Timer?

    init(palette: GlassPalette) {
        super.init(frame: NSRect(x: 0, y: 0, width: 228, height: 132))
        let style = DesktopConfiguration.Surface(display: .always, edge: .bottom, opacity: 0.92, blur: true, size: 32, radius: 18)
        addSubview(palette.surface(frame: bounds, style: style))
        field.textColor = palette.text
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        field.frame = bounds.insetBy(dx: 16, dy: 15)
        addSubview(field)
        refresh()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func refresh() {
        let cpu = stats.load().map { "\($0)%" } ?? "—"
        field.stringValue = "SYSTEM STATUS\n\nCPU      \(cpu)\nRAM      \(SystemWidgets.memory)\nNETWORK  \(SystemWidgets.network ?? "Offline")\nPOWER    \(SystemWidgets.battery ?? "AC / no battery")"
    }

    deinit { timer?.invalidate() }
}
