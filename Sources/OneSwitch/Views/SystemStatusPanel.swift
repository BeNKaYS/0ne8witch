import SwiftUI
import Darwin
import IOKit.ps
import AppKit

// MARK: - Ölçüm modeli

/// Panel açıkken saniyede bir örnek alan canlı sistem ölçümleri.
///
/// Tüm değerler doğrudan Mach / IOKit API'lerinden okunur; kabuk komutu
/// yalnızca ağ baytları için (`netstat`) kullanılır.
@MainActor
public final class SystemStatusModel: ObservableObject {
    @Published public var cpu: Double = 0
    @Published public var memoryUsed: UInt64 = 0
    @Published public var memoryTotal: UInt64 = 0
    @Published public var diskUsed: UInt64 = 0
    @Published public var diskTotal: UInt64 = 0
    @Published public var downloadRate: Double = 0
    @Published public var uploadRate: Double = 0
    @Published public var batteryLevel: Int? = nil
    @Published public var isCharging: Bool = false
    @Published public var uptime: TimeInterval = 0
    @Published public var loadAverage: Double = 0
    @Published public var processCount: Int = 0

    private var timer: Timer?
    private var previousBusy: UInt32 = 0
    private var previousIdle: UInt32 = 0
    private var previousIn: UInt64 = 0
    private var previousOut: UInt64 = 0
    private var previousSampleDate: Date = Date()

    public init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    deinit {
        timer?.invalidate()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func refresh() {
        sampleCPU()
        sampleMemory()
        sampleDisk()
        sampleNetwork()
        sampleBattery()
        uptime = ProcessInfo.processInfo.systemUptime
        loadAverage = ProcessInfo.processInfo.systemUptime > 0
            ? SystemStatusModel.loadAverage1m()
            : 0
        processCount = SystemStatusModel.runningProcessCount()
    }

    // MARK: CPU

    private func sampleCPU() {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )
        guard result == KERN_SUCCESS, let info else { return }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        var busy: UInt32 = 0
        var idle: UInt32 = 0
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * Int(CPU_STATE_MAX)
            busy = busy &+ UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])
            busy = busy &+ UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])
            busy = busy &+ UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            idle = idle &+ UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
        }

        let busyDelta = Double(busy &- previousBusy)
        let idleDelta = Double(idle &- previousIdle)
        let total = busyDelta + idleDelta
        previousBusy = busy
        previousIdle = idle
        guard total > 0 else { return }
        cpu = max(0, min(100, busyDelta / total * 100))
    }

    // MARK: Bellek

    private func sampleMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)

        let active = UInt64(stats.active_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        memoryUsed = active + wired + compressed
        memoryTotal = ProcessInfo.processInfo.physicalMemory
    }

    // MARK: Disk

    private func sampleDisk() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return }
        let total = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
        let free = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        diskTotal = total
        diskUsed = total > free ? total - free : 0
    }

    // MARK: Ağ

    private func sampleNetwork() {
        let output = CommandRunner.shared.runShell("netstat -ibn 2>/dev/null").output
        guard let (bytesIn, bytesOut) = SystemStatusModel.parseNetstat(output) else { return }

        let now = Date()
        let elapsed = now.timeIntervalSince(previousSampleDate)

        if previousIn > 0, bytesIn >= previousIn, elapsed > 0.2 {
            downloadRate = Double(bytesIn - previousIn) / elapsed
            uploadRate = Double(bytesOut - previousOut) / elapsed
        } else {
            downloadRate = 0
            uploadRate = 0
        }

        previousIn = bytesIn
        previousOut = bytesOut
        previousSampleDate = now
    }

    /// `netstat -ibn` çıktısından toplam gelen/giden baytı çıkarır.
    ///
    /// Link satırlarında Address sütunu boş olduğu için sütunlar bir kayar;
    /// bu yüzden sabit sıra yerine `<Link#…>` işareti aranır. Sanal
    /// arayüzler (loopback, VPN tünelleri) sayılmaz, aksi hâlde trafik
    /// iki kez toplanır.
    nonisolated static func parseNetstat(_ output: String) -> (UInt64, UInt64)? {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var found = false

        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard let linkIndex = fields.firstIndex(where: { $0.hasPrefix("<Link#") })
            else { continue }

            let name = fields[0]
            let ignoredPrefixes = ["lo", "utun", "gif", "stf", "awdl", "llw", "bridge", "ap", "anpi"]
            if ignoredPrefixes.contains(where: { name.hasPrefix($0) }) { continue }

            // Satır sonu her zaman: Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
            // olduğu için baytlar sondan sayılır; Address sütununun boş ya da
            // dolu olması sonucu değiştirmez.
            let count = fields.count
            guard count >= 8,
                  let incoming = UInt64(fields[count - 5]),
                  let outgoing = UInt64(fields[count - 2])
            else { continue }

            bytesIn += incoming
            bytesOut += outgoing
            found = true
        }
        return found ? (bytesIn, bytesOut) : nil
    }

    // MARK: Pil

    private func sampleBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            if let capacity = description[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = description[kIOPSMaxCapacityKey] as? Int,
               maxCapacity > 0 {
                batteryLevel = Int(round(Double(capacity) / Double(maxCapacity) * 100))
                isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
                return
            }
        }
    }

    // MARK: Yardımcılar

    nonisolated static func loadAverage1m() -> Double {
        var load = [Double](repeating: 0, count: 3)
        let result = getloadavg(&load, 3)
        return result > 0 ? load[0] : 0
    }

    nonisolated static func runningProcessCount() -> Int {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return 0 }
        let count = size / MemoryLayout<kinfo_proc>.stride
        return count
    }
}

// MARK: - Panel görünümü

public struct SystemStatusPanel: View {
    @StateObject private var model = SystemStatusModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sistem Durumu")
                    .font(.system(size: 15, weight: .semibold))
                Text("Saniyede bir yenilenir")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            metric(
                title: "İşlemci",
                value: String(format: "%%%.0f", model.cpu),
                fraction: model.cpu / 100,
                detail: String(format: "%.2f ortalama yük · %d süreç", model.loadAverage, model.processCount)
            )

            metric(
                title: "Bellek",
                value: byteString(model.memoryUsed),
                fraction: ratio(model.memoryUsed, model.memoryTotal),
                detail: "\(byteString(model.memoryTotal)) toplam"
            )

            metric(
                title: "Disk",
                value: byteString(model.diskUsed),
                fraction: ratio(model.diskUsed, model.diskTotal),
                detail: "\(byteString(model.diskTotal)) toplam · \(byteString(model.diskTotal - model.diskUsed)) boş"
            )

            Divider()

            HStack(spacing: 18) {
                rateBlock(
                    icon: "arrow.down",
                    title: "İndirme",
                    value: rateString(model.downloadRate)
                )
                rateBlock(
                    icon: "arrow.up",
                    title: "Yükleme",
                    value: rateString(model.uploadRate)
                )
            }

            Divider()

            HStack {
                detailRow(
                    icon: model.isCharging ? "battery.100.bolt" : "battery.75",
                    text: batteryText
                )
                Spacer()
                detailRow(icon: "clock", text: "Açık: \(uptimeString)")
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear { model.stop() }
    }

    private var batteryText: String {
        guard let level = model.batteryLevel else { return "Pil yok" }
        return model.isCharging ? "Pil %\(level) · şarjda" : "Pil %\(level)"
    }

    private var uptimeString: String {
        let total = Int(model.uptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)g \(hours)s" }
        if hours > 0 { return "\(hours)s \(minutes)dk" }
        return "\(minutes)dk"
    }

    private func metric(title: String, value: String, fraction: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.16))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(fraction))
                        .frame(width: max(0, min(1, fraction)) * geo.size.width)
                }
            }
            .frame(height: 6)
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
        }
    }

    private func rateBlock(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.active)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private func barColor(_ fraction: Double) -> Color {
        if fraction > 0.9 { return .red }
        if fraction > 0.75 { return .orange }
        return AppTheme.active
    }

    private func ratio(_ part: UInt64, _ whole: UInt64) -> Double {
        whole > 0 ? Double(part) / Double(whole) : 0
    }

    private func byteString(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private func rateString(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 1 else { return "0 B/s" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }
}
