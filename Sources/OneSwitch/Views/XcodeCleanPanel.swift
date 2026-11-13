import SwiftUI
import AppKit
import Foundation

/// Xcode temizliği için tek bir kategori (DerivedData, cihaz desteği…).
public struct XcodeCleanItem: Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let urls: [URL]
    public var size: UInt64
    public var selected: Bool
}

/// Xcode'un ürettiği ara dosyaları tarar ve Çöp Kutusu'na taşır.
///
/// Silme işlemi `rm -rf` değil, `trashItem` ile yapılır: kullanıcı yanlış
/// seçim yaptıysa Çöp Kutusu'ndan geri alabilir.
@MainActor
public final class XcodeCleanModel: ObservableObject {
    @Published public var items: [XcodeCleanItem] = []
    @Published public var isScanning = false
    @Published public var isCleaning = false
    @Published public var statusMessage: String? = nil

    public init() {}

    public var totalSize: UInt64 {
        items.filter(\.selected).reduce(0) { $0 + $1.size }
    }

    public var hasSelection: Bool {
        items.contains { $0.selected && $0.size > 0 }
    }

    public func scan() async {
        isScanning = true
        statusMessage = nil

        let scanned = await Task.detached(priority: .userInitiated) {
            XcodeCleanModel.buildItems()
        }.value

        items = scanned
        isScanning = false
    }

    public func toggle(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].selected.toggle()
    }

    public func selectAll(_ selected: Bool) {
        for index in items.indices where items[index].size > 0 {
            items[index].selected = selected
        }
    }

    public func clean() async {
        let targets = items.filter { $0.selected && !$0.urls.isEmpty }
        guard !targets.isEmpty else { return }

        isCleaning = true
        let urls = targets.flatMap(\.urls)

        let result = await Task.detached(priority: .userInitiated) { () -> (Int, Int) in
            var moved = 0
            var failed = 0
            for url in urls {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    moved += 1
                } catch {
                    failed += 1
                }
            }
            return (moved, failed)
        }.value

        isCleaning = false
        if result.1 == 0 {
            statusMessage = "\(result.0) öğe Çöp Kutusu'na taşındı."
        } else {
            statusMessage = "\(result.0) öğe taşındı, \(result.1) öğe taşınamadı."
        }
        await scan()
    }

    // MARK: Tarama

    nonisolated static func buildItems() -> [XcodeCleanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Developer", isDirectory: true)

        func children(_ url: URL) -> [URL] {
            (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
        }

        var deviceSupport: [URL] = []
        for folder in [
            "iOS DeviceSupport", "tvOS DeviceSupport", "watchOS DeviceSupport",
            "visionOS DeviceSupport", "macOS DeviceSupport"
        ] {
            deviceSupport.append(contentsOf: children(home.appendingPathComponent("Xcode/\(folder)")))
        }

        let raw: [(String, String, String, [URL])] = [
            (
                "derived_data",
                "DerivedData",
                "Proje indeksleri ve derleme çıktıları. Xcode yeniden oluşturur.",
                children(home.appendingPathComponent("Xcode/DerivedData"))
            ),
            (
                "device_support",
                "Cihaz Desteği",
                "Eski iOS/watchOS sürümlerinin sembol dosyaları.",
                deviceSupport
            ),
            (
                "archives",
                "Arşivler",
                "App Store'a gönderilmiş .xcarchive paketleri.",
                children(home.appendingPathComponent("Xcode/Archives"))
            ),
            (
                "simulator_caches",
                "Simülatör Önbelleği",
                "CoreSimulator'ın geçici önbellek dosyaları.",
                children(home.appendingPathComponent("CoreSimulator/Caches"))
            ),
            (
                "previews",
                "Önizlemeler",
                "SwiftUI Preview'ların ürettiği geçici derlemeler.",
                children(home.appendingPathComponent("Xcode/UserData/Previews"))
            )
        ]

        // Boyut hesabı kategori başına yapılır; boş kategoriler yine listelenir.
        return raw.map { id, title, detail, urls in
            XcodeCleanItem(
                id: id,
                title: title,
                detail: detail,
                urls: urls,
                size: allocatedSize(of: urls),
                selected: !urls.isEmpty
            )
        }
    }

    nonisolated static func allocatedSize(of urls: [URL]) -> UInt64 {
        var total: UInt64 = 0
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        for url in urls {
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let file as URL in enumerator {
                let values = try? file.resourceValues(forKeys: keys)
                total += UInt64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            }
        }
        return total
    }
}

public struct XcodeCleanPanel: View {
    @StateObject private var model = XcodeCleanModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Xcode Derin Temizlik")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Seçilenler Çöp Kutusu'na taşınır, silinmez.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Yenile") {
                        Task { await model.scan() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.active)
                }
            }

            VStack(spacing: 5) {
                ForEach(model.items) { item in
                    row(item)
                }
            }

            HStack {
                Button(model.items.contains(where: \.selected) ? "Hiçbirini seçme" : "Tümünü seç") {
                    model.selectAll(!model.items.contains(where: \.selected))
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                Spacer()
            }

            if let message = model.statusMessage {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Seçili toplam")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                    Text(sizeString(model.totalSize))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                Spacer()
                Button(model.isCleaning ? "Temizleniyor…" : "Temizle") {
                    confirmClean()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.active)
                .disabled(!model.hasSelection || model.isCleaning || model.isScanning)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if model.items.isEmpty { await model.scan() }
        }
    }

    private func row(_ item: XcodeCleanItem) -> some View {
        Button {
            model.toggle(item.id)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: item.selected && item.size > 0
                      ? "checkmark.square.fill"
                      : "square")
                    .font(.system(size: 12))
                    .foregroundStyle(item.selected && item.size > 0 ? AppTheme.active : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 11.5, weight: .medium))
                        Text(item.urls.isEmpty ? "yok" : "\(item.urls.count) öğe")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    Text(item.detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Text(sizeString(item.size))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(item.size > 0 ? .primary : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(item.selected && item.size > 0
                      ? AppTheme.active.opacity(0.10)
                      : Color.secondary.opacity(0.06))
        )
        .opacity(item.urls.isEmpty ? 0.45 : 1)
    }

    private func confirmClean() {
        let alert = NSAlert()
        alert.messageText = "\(sizeString(model.totalSize)) Çöp Kutusu'na taşınsın mı?"
        alert.informativeText = "Xcode bir sonraki derlemede bu dosyaları yeniden oluşturur. Taşınanlar Çöp Kutusu'ndan geri alınabilir."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Temizle")
        alert.addButton(withTitle: "Vazgeç")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { await model.clean() }
    }

    private func sizeString(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
