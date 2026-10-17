import Foundation
import ServiceManagement
import SwiftUI
import Combine

/// Uygulama ayarlarını yöneten ve UserDefaults ile senkronize çalışan yönetici
public final class PreferencesManager: ObservableObject {
    public static let shared = PreferencesManager()
    
    private let defaults = UserDefaults.standard
    
    // Ayar Anahtarları
    private let kLaunchAtLogin = "kLaunchAtLogin"
    private let kShowNotifications = "kShowNotifications"
    private let kPlaySounds = "kPlaySounds"
    private let kMenuBarIcon = "kMenuBarIcon"
    private let kVisibleSwitchIDs = "kVisibleSwitchIDs"
    
    @Published public var launchAtLogin: Bool = false
    @Published public var showNotifications: Bool = true
    @Published public var playSounds: Bool = false
    @Published public var menuBarIcon: String = "switch.2"
    @Published public var visibleSwitchIDs: Set<String> = []
    @Published public var selectedTab: Int = 0
    
    public let availableIcons: [(id: String, name: String)] = [
        ("switch.2", "Çift Anahtar (Varsayılan)"),
        ("AppLogo", "0ne8witch Logosu (Özel İkon)"),
        ("togglepower", "Aç/Kapa Güç Anahtarı"),
        ("slider.horizontal.3", "Ayarlar / Kaydırıcı"),
        ("slider.horizontal.2.square.on.square", "Kontrol Merkezi"),
        ("power", "Klasik Güç Düğmesi"),
        ("bolt.fill", "Şimşek / Hızlı Eylem"),
        ("command", "Komut Simgesi (⌘)"),
        ("wand.and.stars", "Sihirli Değnek"),
        ("dial.low.fill", "Ayar Kadranı"),
        ("macwindow.on.rectangle", "Pencereler & Ekran"),
        ("sparkles", "Temizlik & Parlaklık"),
        ("gearshape.2.fill", "Sistem Çarkları")
    ]
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        self.showNotifications = defaults.object(forKey: kShowNotifications) as? Bool ?? true
        self.playSounds = defaults.bool(forKey: kPlaySounds)
        self.menuBarIcon = defaults.string(forKey: kMenuBarIcon) ?? "switch.2"
        
        // Görünür anahtarlar (Varsayılan olarak tümü görünür)
        if let savedIDs = defaults.array(forKey: kVisibleSwitchIDs) as? [String] {
            self.visibleSwitchIDs = Set(savedIDs)
        } else {
            // İlk açılışta hepsi görünür
            self.visibleSwitchIDs = [
                "presentation_mode", "keep_awake", "dark_mode", "desktop_icons", "hidden_files",
                "file_extensions", "user_library", "mute_microphone", "stage_manager",
                "hide_widgets", "dock_autohide", "screen_clean", "low_power_mode", "natural_scroll"
            ]
        }
        
        // Başlangıçta açılma durumu (SMAppService kontrolü)
        if #available(macOS 13.0, *) {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            self.launchAtLogin = defaults.bool(forKey: kLaunchAtLogin)
        }
    }
    
    /// Başlangıçta açılma durumunu değiştirir
    public func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                self.launchAtLogin = enable
                defaults.set(enable, forKey: kLaunchAtLogin)
            } catch {
                print("LaunchAtLogin hatası: \(error)")
                self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        } else {
            self.launchAtLogin = enable
            defaults.set(enable, forKey: kLaunchAtLogin)
        }
    }
    
    public func setShowNotifications(_ val: Bool) {
        self.showNotifications = val
        defaults.set(val, forKey: kShowNotifications)
    }
    
    public func setPlaySounds(_ val: Bool) {
        self.playSounds = val
        defaults.set(val, forKey: kPlaySounds)
    }
    
    public func setMenuBarIcon(_ icon: String) {
        self.menuBarIcon = icon
        defaults.set(icon, forKey: kMenuBarIcon)
        NotificationCenter.default.post(name: .menuBarIconDidChange, object: icon)
    }
    
    public func toggleSwitchVisibility(id: String) {
        if visibleSwitchIDs.contains(id) {
            // En az bir anahtar görünür kalmalı
            if visibleSwitchIDs.count > 1 {
                visibleSwitchIDs.remove(id)
            }
        } else {
            visibleSwitchIDs.insert(id)
        }
        defaults.set(Array(visibleSwitchIDs), forKey: kVisibleSwitchIDs)
    }
    
    public func isSwitchVisible(id: String) -> Bool {
        return visibleSwitchIDs.contains(id)
    }
}

extension Notification.Name {
    public static let menuBarIconDidChange = Notification.Name("menuBarIconDidChange")
}
