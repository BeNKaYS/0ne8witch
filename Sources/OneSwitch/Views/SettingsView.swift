import SwiftUI
import AppKit

/// macOS Yerel Ayarlar Penceresi Görünümü
public struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var switchManager = SwitchManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Sekme Başlıkları
            HStack(spacing: 16) {
                TabButton(title: "Genel", icon: "gearshape", tag: 0, currentTab: prefs.selectedTab) {
                    prefs.selectedTab = 0
                }
                TabButton(title: "Anahtarları Özelleştir", icon: "slider.horizontal.3", tag: 1, currentTab: prefs.selectedTab) {
                    prefs.selectedTab = 1
                }
                TabButton(title: "Guncellemeler", icon: "arrow.down.circle", tag: 3, currentTab: prefs.selectedTab) {
                    prefs.selectedTab = 3
                }
                TabButton(title: "Hakkında", icon: "info.circle", tag: 2, currentTab: prefs.selectedTab) {
                    prefs.selectedTab = 2
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // Sekme İçerikleri
            Group {
                if prefs.selectedTab == 0 {
                    GeneralSettingsView()
                } else if prefs.selectedTab == 1 {
                    CustomizeSwitchesView()
                } else if prefs.selectedTab == 3 {
                    UpdateSettingsView()
                } else {
                    AboutSettingsView()
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
            
            // Alt Kapatma Çubuğu
            HStack {
                Spacer()
                Button("Tamam") {
                    SettingsWindowController.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 600, minHeight: 540)
    }
}

// MARK: - Sekme Butonu
private struct TabButton: View {
    let title: String
    let icon: String
    let tag: Int
    let currentTab: Int
    let action: () -> Void
    
    var isSelected: Bool { tag == currentTab }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Genel Ayarlar Sekmesi
private struct GeneralSettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    
    var body: some View {
        // İçerik pencereye sığsa da taşsa da asla kesilmesin diye kaydırılabilir alan
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Başlangıçta Açıl
                Toggle("Sistem Başlangıcında Aç", isOn: Binding(
                    get: { prefs.launchAtLogin },
                    set: { prefs.setLaunchAtLogin($0) }
                ))
                .font(.system(size: 13, weight: .medium))
                
                Text("Mac'iniz açıldığında 0ne8witch otomatik olarak menü çubuğunda çalışır.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                // Bildirimler
                Toggle("Durum Değişikliklerinde Bildirim Göster", isOn: Binding(
                    get: { prefs.showNotifications },
                    set: { prefs.setShowNotifications($0) }
                ))
                .font(.system(size: 13, weight: .medium))
                
                Text("Bir anahtar tetiklendiğinde ekranın altında küçük bilgi mesajı görüntülenir.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Menü Çubuğu Simgesi
                VStack(alignment: .leading, spacing: 10) {
                    Text("Menü Çubuğu Simgesi")
                        .font(.system(size: 13, weight: .medium))
                    
                    Text("Menü çubuğunda görünecek simgeyi seçin.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    // İki satır (7 + 6) simge ızgarası
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7),
                        spacing: 12
                    ) {
                        ForEach(prefs.availableIcons, id: \.id) { iconItem in
                            MenuBarIconButton(
                                iconID: iconItem.id,
                                tooltip: iconItem.name,
                                isSelected: prefs.menuBarIcon == iconItem.id
                            ) {
                                prefs.setMenuBarIcon(iconItem.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Menü Çubuğu Simgesi Seçim Butonu
private struct MenuBarIconButton: View {
    let iconID: String
    let tooltip: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                        .frame(width: 44, height: 44)
                    
                    iconView
                }
                .frame(maxWidth: .infinity)
                
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                } else {
                    Spacer().frame(height: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }
    
    /// "AppLogo" özel resimdir, diğerleri SF Symbol'dır
    @ViewBuilder private var iconView: some View {
        if iconID == "AppLogo", let img = Self.customLogo() {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        } else if iconID == "AppLogo" {
            // Resim bulunamazsa simge kutusu boş kalmasın
            Image(systemName: "app.badge")
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .accentColor : .primary)
        } else {
            Image(systemName: iconID)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
    }
    
    private static func customLogo() -> NSImage? {
        let paths = [
            "Sources/OneSwitch/Resources/app_icon.png",
            "../Resources/app_icon.png",
            "OneSwitch.app/Contents/Resources/app_icon.png",
            "0ne8witch.app/Contents/Resources/app_icon.png"
        ]
        if let url = Bundle.main.url(forResource: "app_icon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        for path in paths {
            if let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        return NSImage(named: "AppIcon")
    }
}

// MARK: - Anahtarları Özelleştir Sekmesi
private struct CustomizeSwitchesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var switchManager = SwitchManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menü Çubuğunda Gösterilecek Anahtarları Seçin:")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            
            List {
                ForEach(switchManager.allSwitches, id: \.id) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(item.activeColor)
                            .frame(width: 20)
                        
                        Text(item.title)
                            .font(.system(size: 13))
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { prefs.isSwitchVisible(id: item.id) },
                            set: { _ in prefs.toggleSwitchVisibility(id: item.id) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                }
            }
            .listStyle(.inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Hakkında Sekmesi (Geliştirici Kartı)
private struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            DeveloperCardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
    }
}
