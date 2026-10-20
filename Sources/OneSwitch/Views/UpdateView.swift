import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Ayarlar penceresindeki "Guncellemeler" sekmesi
public struct UpdateSettingsView: View {
    @ObservedObject var updater = UpdateManager.shared
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Durum kartı
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                        Text("Uygulama Guncellemeleri")
                            .font(.system(size: 15, weight: .bold))
                    }

                    HStack {
                        Text("Mevcut Surum:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("\(updater.currentVersion) (build \(updater.currentBuild))")
                            .font(.system(size: 12, weight: .semibold))
                    }

                    if !updater.latestVersion.isEmpty {
                        HStack {
                            Text("Son Kontrol:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            if let d = updater.lastChecked {
                                Text(d, style: .relative)
                                    .font(.system(size: 12))
                            } else {
                                Text("-")
                                    .font(.system(size: 12))
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )

                // Durum mesajı
                statusView

                // Aksiyon butonları
                HStack(spacing: 10) {
                    Button(action: {
                        updater.checkForUpdates()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("GitHub'dan Kontrol Et")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .disabled(isBusy)

                    Button(action: chooseLocalPackage) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                            Text("Yerel Dosyadan Guncelle...")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .disabled(isBusy)

                    if case .available = updater.state {
                        Button(action: {
                            updater.downloadUpdate()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.to.line")
                                Text("Indir")
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if case .readyToInstall = updater.state {
                        Button(action: {
                            updater.installUpdate()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Kur ve Yeniden Baslat")
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if case .downloading = updater.state {
                        Button(action: {
                            updater.cancelDownload()
                        }) {
                            Text("Iptal")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                }

                // Indirme ilerlemesi
                if case .downloading(let p) = updater.state {
                    ProgressView(value: p)
                        .progressViewStyle(.linear)
                    Text("Indiriliyor: %\(Int(p * 100))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // Surum notlari
                if !updater.releaseNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Surum Notlari")
                            .font(.system(size: 12, weight: .semibold))
                        ScrollView {
                            Text(updater.releaseNotes)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }

                Divider().padding(.vertical, 6)

                // Guncelleme kaynagi ayari
                VStack(alignment: .leading, spacing: 8) {
                    Text("Guncelleme Kaynagi")
                        .font(.system(size: 12, weight: .semibold))
                    Text("GitHub Releases veya ozel bir JSON manifest adresi.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    TextField("https://...", text: Binding(get: { updater.feedURL }, set: { updater.feedURL = $0 }))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    Text("Degisiklikler otomatik kaydedilir.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text("GitHub uzerinden guncelleme icin depo herkese acik olmali ve Releases bolumunde .zip dosyasi bulunmalidir. Aksi halde yerel dosyadan guncellemeyi kullanin.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chooseLocalPackage() {
        let panel = NSOpenPanel()
        panel.title = "Guncelleme Dosyasi Sec"
        panel.message = "Indirdiginiz .zip veya .app dosyasini secin."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        var types: [UTType] = [.zip]
        if let appType = UTType(filenameExtension: "app") {
            types.append(appType)
        }
        panel.allowedContentTypes = types

        if panel.runModal() == .OK, let url = panel.url {
            updater.installLocalPackage(from: url)
        }
    }

    private var isBusy: Bool {
        switch updater.state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Kontrol ediliyor...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Uygulamaniz guncel.")
                    .font(.system(size: 12, weight: .medium))
            }
        case .available(let v, _):
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill").foregroundColor(.orange)
                Text("Yeni surum mevcut: \(v)")
                    .font(.system(size: 12, weight: .medium))
            }
        case .downloading:
            EmptyView()
        case .readyToInstall:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Indirme tamamlandi. Kurulum icin butona tiklayin.")
                    .font(.system(size: 12, weight: .medium))
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Kuruluyor ve yeniden baslatiliyor...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        case .error(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
}
