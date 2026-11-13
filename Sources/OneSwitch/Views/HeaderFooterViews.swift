import SwiftUI
import AppKit

/// Menünün üst başlık çubuğu
public struct HeaderView: View {
    @ObservedObject var manager = SwitchManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "switch.2")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(AppTheme.active)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("0ne8witch")
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 8) {
                    StatMeter(label: "CPU", text: systemMonitor.cpuUsageText)
                    StatMeter(label: "RAM", text: systemMonitor.memoryUsageText)
                }
            }

            Spacer()

            HStack(spacing: 2) {
                HeaderIconButton(icon: "arrow.clockwise", help: "Durumları yenile") {
                    SystemStateReader.shared.invalidate()
                    systemMonitor.updateStats()
                    SystemStateReader.shared.prewarmAsync {
                        manager.refreshAll()
                        manager.showNotification("Durumlar yenilendi")
                    }
                }
                HeaderIconButton(icon: "gearshape", help: "Ayarlar") {
                    SettingsWindowController.shared.showSettings()
                }
                HeaderIconButton(icon: "power", help: "Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }
}

/// "%42" biçimindeki değeri küçük bir dolum çubuğuyla gösterir.
private struct StatMeter: View {
    let label: String
    let text: String

    private var fraction: Double {
        let digits = text.filter(\.isNumber)
        return min(1, max(0, (Double(digits) ?? 0) / 100))
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(fraction > 0.85 ? Color.red : AppTheme.active)
                    .frame(width: 28 * fraction)
            }
            .frame(width: 28, height: 4)
            Text(text)
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 26, alignment: .leading)
        }
        .help("\(label) kullanımı \(text)")
        .accessibilityElement(children: .combine)
    }
}

/// Başlıktaki sabit boyutlu, hover vurgulu ikon butonu
private struct HeaderIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(hovering ? .primary : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(hovering ? 0.08 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Tek tıkla çalışan Hızlı Eylemler Çubuğu (Geliştirici & Sistem Araçları)
public struct QuickActionsBar: View {
    @ObservedObject var prefs = PreferencesManager.shared

    public var body: some View {
        let actions = prefs.visibleQuickActions
        if actions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Hızlı Eylemler")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                    spacing: 6
                ) {
                    ForEach(actions) { kind in
                        QuickActionButton(
                            icon: kind.icon,
                            label: kind.label,
                            action: { kind.perform() }
                        )
                        .help(kind.detail)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

public struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(hovering ? AppTheme.active : .primary)
                    .frame(height: 16)
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.09 : 0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
    }
}

/// Kısa süreli bilgilendirme mesajı (altta yüzen bildirim)
public struct NotificationBanner: View {
    @ObservedObject var manager = SwitchManager.shared

    public var body: some View {
        if let notif = manager.statusNotification {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.active)
                    .font(.system(size: 11))
                Text(notif)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
