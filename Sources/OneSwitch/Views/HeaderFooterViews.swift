import SwiftUI
import AppKit

/// Menünün üst başlık ve arama çubuğu
public struct HeaderView: View {
    @ObservedObject var manager = SwitchManager.shared
    @ObservedObject var systemMonitor = SystemMonitor.shared
    
    public var body: some View {
        VStack(spacing: 10) {
            // Üst Başlık Satırı
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "switch.2")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                    
                    Text("0ne8witch")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    
                    // Mini Sistem Göstergesi (CPU & RAM)
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                        Text(systemMonitor.cpuUsageText)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        
                        Text("•")
                            .font(.system(size: 8))
                            .opacity(0.3)
                        
                        Image(systemName: "memorychip")
                            .font(.system(size: 9))
                        Text(systemMonitor.memoryUsageText)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    // Çıkış Butonu
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Çıkış")
                    
                    // Yenile Butonu
                    Button(action: {
                        SystemStateReader.shared.invalidate()
                        manager.refreshAll()
                        systemMonitor.updateStats()
                        manager.showNotification("Durumlar yenilendi")
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Durumları Yenile")
                    
                    // Ayarlar Butonu
                    Button(action: {
                        SettingsWindowController.shared.showSettings()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Ayarlar...")
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            
            // Arama Kutusu
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField("Anahtar veya özellik ara...", text: $manager.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !manager.searchText.isEmpty {
                    Button(action: { manager.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .padding(.horizontal, 12)
            
            // Kategori Çipleri
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SwitchCategory.allCases) { cat in
                        Button(action: {
                            manager.selectedCategory = cat
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 10))
                                Text(cat.rawValue)
                                    .font(.system(size: 11, weight: manager.selectedCategory == cat ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(manager.selectedCategory == cat ? AppTheme.active : Color.primary.opacity(0.06))
                            )
                            .foregroundColor(manager.selectedCategory == cat ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
}

/// Tek tıkla çalışan Hızlı Eylemler Çubuğu (Geliştirici & Sistem Araçları)
public struct QuickActionsBar: View {
    @ObservedObject var manager = SwitchManager.shared
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HIZLI EYLEMLER & ARAÇLAR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 14)
            
            HStack(spacing: 6) {
                // Çöp Kutusunu Boşalt
                QuickActionButton(
                    icon: "trash",
                    label: "Çöpü Boşalt",
                    action: {
                        QuickActions.shared.emptyTrash { message in
                            manager.showNotification(message)
                        }
                    }
                )
                
                // Port Temizleyici (Port Killer)
                QuickActionButton(
                    icon: "network",
                    label: "Port Temizle",
                    action: {
                        QuickActions.shared.killDevPorts { message in
                            manager.showNotification(message)
                        }
                    }
                )
                
                // Grupları ayıran dikey çizgi
                QuickActionSeparator()
                
                // Diskleri Çıkar
                QuickActionButton(
                    icon: "eject.fill",
                    label: "Diskleri Çıkar",
                    action: {
                        QuickActions.shared.ejectAllDisks { message in
                            manager.showNotification(message)
                        }
                    }
                )
                
                // RAM Temizle
                QuickActionButton(
                    icon: "memorychip",
                    label: "RAM Temizle",
                    action: {
                        QuickActions.shared.purgeMemory { message in
                            manager.showNotification(message)
                        }
                    }
                )
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }
}

/// Hızlı eylem gruplarını birbirinden ayıran dikey çizgi.
/// Açık ve koyu temada aynı şekilde okunur.
public struct QuickActionSeparator: View {
    public init() {}
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 0.5, style: .continuous)
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 1)
    }
}

public struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Kısa süreli bilgilendirme mesajı
public struct NotificationBanner: View {
    @ObservedObject var manager = SwitchManager.shared
    
    public var body: some View {
        if let notif = manager.statusNotification {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text(notif)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
            .transition(.opacity.combined(with: .scale))
            .padding(.bottom, 6)
        }
    }
}
