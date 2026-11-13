import SwiftUI
import AppKit
import Foundation

// MARK: - Model

/// Yerel IP, dış IP, konum ve bağlantı kalitesini toplayan model.
@MainActor
public final class IPOverviewModel: ObservableObject {
    @Published public var localIP: String = "—"
    @Published public var interfaceName: String = ""
    @Published public var publicIP: String = "—"
    @Published public var location: String = "—"
    @Published public var provider: String = "—"
    @Published public var latency: Double? = nil
    @Published public var packetLoss: Double? = nil
    @Published public var gateway: String = "—"
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var lastUpdate: Date? = nil
    @Published public var copied: Bool = false

    public init() {
        readLocalAddress()
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        readLocalAddress()
        readGateway()

        async let quality = measureLatency()
        async let publicInfo = fetchPublicInfo()

        let (qualityResult, info) = await (quality, publicInfo)

        latency = qualityResult?.latency
        packetLoss = qualityResult?.loss

        if let info {
            publicIP = info.ip
            if let city = info.city, let country = info.country {
                location = "\(city), \(country)"
            } else if let country = info.country {
                location = country
            }
            provider = info.org ?? "—"
        } else if errorMessage == nil {
            errorMessage = "Dış IP alınamadı. Bağlantıyı kontrol edin."
        }

        if publicIP == "—", let ip = info?.ip { publicIP = ip }
        lastUpdate = Date()
        isLoading = false
    }

    public var summaryText: String {
        var lines: [String] = []
        lines.append("Yerel IP: \(localIP)\(interfaceName.isEmpty ? "" : " (\(interfaceName))")")
        lines.append("Ağ geçidi: \(gateway)")
        lines.append("Dış IP: \(publicIP)")
        lines.append("Konum: \(location)")
        lines.append("Sağlayıcı: \(provider)")
        if let latency { lines.append(String(format: "Gecikme: %.0f ms", latency)) }
        if let packetLoss { lines.append(String(format: "Paket kaybı: %%%.0f", packetLoss)) }
        return lines.joined(separator: "\n")
    }

    public func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(summaryText, forType: .string)
        copied = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            copied = false
        }
    }

    // MARK: Yerel adres

    private func readLocalAddress() {
        var candidates: [(name: String, ip: String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var pointer = first
        while true {
            let flags = Int32(pointer.pointee.ifa_flags)
            if (flags & IFF_UP) != 0,
               (flags & IFF_LOOPBACK) == 0,
               let addr = pointer.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    addr,
                    socklen_t(addr.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    let ip = String(cString: host)
                    let name = String(cString: pointer.pointee.ifa_name)
                    if !ip.hasPrefix("169.254.") {
                        candidates.append((name, ip))
                    }
                }
            }
            guard let next = pointer.pointee.ifa_next else { break }
            pointer = next
        }

        // Önce Wi-Fi / Ethernet, sonra diğerleri.
        let preferred = candidates.first { $0.name.hasPrefix("en") } ?? candidates.first
        localIP = preferred?.ip ?? "—"
        interfaceName = preferred?.name ?? ""
    }

    private func readGateway() {
        let output = CommandRunner.shared
            .runShell("route -n get default 2>/dev/null | awk '/gateway/ {print $2; exit}'")
            .output
            .trimmingCharacters(in: .whitespacesAndNewlines)
        gateway = output.isEmpty ? "—" : output
    }

    // MARK: Gecikme

    private struct Quality {
        let latency: Double
        let loss: Double
    }

    private func measureLatency() async -> Quality? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let output = CommandRunner.shared
                    .runShell("ping -c 5 -t 4 1.1.1.1 2>/dev/null")
                    .output

                var times: [Double] = []
                for line in output.split(separator: "\n") where line.contains("time=") {
                    guard let range = line.range(of: "time=") else { continue }
                    let tail = line[range.upperBound...]
                    let number = tail.prefix { $0.isNumber || $0 == "." }
                    if let value = Double(number) { times.append(value) }
                }

                var loss: Double = 0
                if let lossRange = output.range(of: "packet loss") {
                    let before = output[..<lossRange.lowerBound]
                    let piece = before.split(separator: " ").last.map(String.init) ?? "0"
                    loss = Double(piece.replacingOccurrences(of: "%", with: "")) ?? 0
                }

                guard let average = times.isEmpty
                    ? nil
                    : times.reduce(0, +) / Double(times.count)
                else {
                    continuation.resume(returning: Quality(latency: 0, loss: loss))
                    return
                }
                continuation.resume(returning: Quality(latency: average, loss: loss))
            }
        }
    }

    // MARK: Dış IP

    private struct PublicInfo {
        let ip: String
        let city: String?
        let country: String?
        let org: String?
    }

    private func fetchPublicInfo() async -> PublicInfo? {
        if let info = await request("https://ipapi.co/json/") {
            return info
        }
        return await request("https://ipinfo.io/json")
    }

    private func request(_ urlString: String) async -> PublicInfo? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("0ne8witch/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ip = json["ip"] as? String
            else { return nil }

            let city = json["city"] as? String
            let country = (json["country_name"] as? String) ?? (json["country"] as? String)
            let org = (json["org"] as? String) ?? (json["isp"] as? String)

            if country == nil, let loc = json["loc"] as? String, loc.contains(",") {
                return PublicInfo(ip: ip, city: city, country: loc, org: org)
            }
            return PublicInfo(ip: ip, city: city, country: country, org: org)
        } catch {
            return nil
        }
    }
}

// MARK: - Görünüm

public struct IPOverviewPanel: View {
    @StateObject private var model = IPOverviewModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IP & Ağ Durumu")
                        .font(.system(size: 15, weight: .semibold))
                    Text(model.lastUpdate.map { "Güncellendi: \(timeString($0))" } ?? "Ölçülüyor…")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: model.isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.active)
                .disabled(model.isLoading)
            }

            VStack(alignment: .leading, spacing: 10) {
                row(icon: "wifi", title: "Yerel IP", value: model.localIP,
                    note: model.interfaceName.isEmpty ? nil : model.interfaceName)
                row(icon: "arrow.triangle.branch", title: "Ağ geçidi", value: model.gateway)
                row(icon: "globe", title: "Dış IP", value: model.publicIP)
                row(icon: "mappin.and.ellipse", title: "Konum", value: model.location)
                row(icon: "building.2", title: "Sağlayıcı", value: model.provider)
            }

            Divider()

            HStack(spacing: 22) {
                quality(
                    title: "Gecikme",
                    value: model.latency.map { String(format: "%.0f ms", $0) } ?? "—",
                    good: (model.latency ?? 999) < 60
                )
                quality(
                    title: "Paket kaybı",
                    value: model.packetLoss.map { String(format: "%%%.0f", $0) } ?? "—",
                    good: (model.packetLoss ?? 999) < 1
                )
            }

            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 0)

            Button {
                model.copy()
            } label: {
                Label(model.copied ? "Kopyalandı" : "Tümünü Kopyala", systemImage: model.copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.active)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await model.load() }
    }

    private func row(icon: String, title: String, value: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            if let note {
                Text(note)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func quality(title: String, value: String, good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Circle()
                    .fill(good ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
