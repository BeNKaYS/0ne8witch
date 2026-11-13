import SwiftUI
import AppKit
import Foundation

/// Kurulu Apple Kısayolları'nı listeleyip çalıştıran panel.
///
/// `shortcuts list` çıktısı isim isim okunur; çalıştırma `shortcuts run`
/// ile yapılır. Bu sayede Rahatsız Etme gibi bir Kısayol'a bağlanan
/// anahtarlar, uygulamaya özel API gerekmeden çalışır.
@MainActor
public final class ShortcutsModel: ObservableObject {
    @Published public var shortcuts: [String] = []
    @Published public var searchText: String = ""
    @Published public var isLoading = false
    @Published public var runningName: String? = nil
    @Published public var statusMessage: String? = nil

    public init() {}

    public var filtered: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return shortcuts }
        return shortcuts.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    public func load() async {
        isLoading = true
        statusMessage = nil
        let list = await Self.readShortcutList()
        shortcuts = list
        isLoading = false
        if list.isEmpty {
            statusMessage = "Kısayol bulunamadı. Kısayollar uygulamasında en az bir tane oluşturun."
        }
    }

    public func run(_ name: String) {
        runningName = name
        statusMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments = ["run", name]
            let pipe = Pipe()
            task.standardError = pipe
            task.standardOutput = pipe

            var message: String
            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if task.terminationStatus == 0 {
                    message = "\"\(name)\" çalıştırıldı."
                } else {
                    message = output.isEmpty
                        ? "\"\(name)\" çalıştırılamadı."
                        : output
                }
            } catch {
                message = "Kısayol çalıştırılamadı: \(error.localizedDescription)"
            }

            DispatchQueue.main.async {
                self.runningName = nil
                self.statusMessage = message
            }
        }
    }

    private static func readShortcutList() async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                task.arguments = ["list"]
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()

                do {
                    try task.run()
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    let names = output
                        .split(separator: "\n")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    continuation.resume(returning: names)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

public struct ShortcutsPanel: View {
    @StateObject private var model = ShortcutsModel()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kısayollar")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(model.shortcuts.count) kısayol · seçip çalıştırın")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.active)
                .disabled(model.isLoading)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                TextField("Ara", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.10))
            )

            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                    Text(model.searchText.isEmpty ? "Kısayol yok" : "Eşleşen kısayol yok")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(model.filtered, id: \.self) { name in
                            row(name)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            if let message = model.statusMessage {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(message.contains("çalıştırıldı") ? Color.secondary : Color.orange)
                    .lineLimit(2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await model.load() }
    }

    private func row(_ name: String) -> some View {
        Button {
            model.run(name)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.active)
                Text(name)
                    .font(.system(size: 11.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if model.runningName == name {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.secondary.opacity(0.07))
        )
        .disabled(model.runningName != nil)
    }
}
