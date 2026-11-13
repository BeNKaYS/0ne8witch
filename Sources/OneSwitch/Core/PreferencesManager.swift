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
    private let kVisibleQuickActionIDs = "kVisibleQuickActionIDs"
    private let kSwitchOrder = "kSwitchOrder"
    private let kQuickActionOrder = "kQuickActionOrder"
    /// Yeni anahtarlar eklendiğinde görünürlük listesini bir kez güncellemek için.
    private let kSwitchSchemaVersion = "kSwitchSchemaVersion"
    private let kQuickActionSchemaVersion = "kQuickActionSchemaVersion"
    private let currentSchemaVersion = 5
    private let currentQuickActionSchemaVersion = 2

    /// Kullanıcı hiçbir anahtarı gizlemediyse görünür kabul edilecek tam liste.
    private static let allSwitchIDs: [String] = [
        "presentation_mode", "keep_awake", "dark_mode", "desktop_icons", "hidden_files",
        "file_extensions", "user_library", "mute_microphone", "stage_manager",
        "hide_widgets", "dock_autohide", "screen_clean", "low_power_mode", "natural_scroll",
        "finder_pathbar", "finder_statusbar", "menubar_autohide", "clock_seconds",
        "dock_magnify", "dock_recents", "ask_password", "wifi_toggle",
        "bluetooth_toggle", "nightshift", "dnd", "airpods", "true_tone",
        "brightness", "hide_notch", "system_mute",
        "screenshot_no_shadow", "dock_show_hidden", "dock_static_only",
        "finder_folders_first", "finder_quit"
    ]

    /// 2. şemada eklenen anahtarlar; göç sırasında yalnızca bunlar açılır.
    private static let schema2SwitchIDs: [String] = [
        "finder_pathbar", "finder_statusbar", "menubar_autohide", "clock_seconds",
        "dock_magnify", "dock_recents", "ask_password", "wifi_toggle",
        "bluetooth_toggle", "nightshift", "dnd", "airpods"
    ]

    /// 3. şemada eklenen anahtarlar.
    private static let schema3SwitchIDs: [String] = ["true_tone", "brightness", "hide_notch"]

    /// 4. şemada eklenen anahtarlar.
    private static let schema4SwitchIDs: [String] = ["system_mute"]

    /// 5. şemada eklenen anahtarlar.
    private static let schema5SwitchIDs: [String] = [
        "screenshot_no_shadow", "dock_show_hidden", "dock_static_only",
        "finder_folders_first", "finder_quit"
    ]

    /// 2. hızlı eylem şemasında eklenen eylemler.
    private static let schema2QuickActionIDs: [String] = [
        "ip_overview", "system_status", "xcode_clean_full",
        "shortcuts", "system_power", "soft_restart"
    ]
    
    @Published public var launchAtLogin: Bool = false
    @Published public var showNotifications: Bool = true
    @Published public var playSounds: Bool = false
    @Published public var menuBarIcon: String = "switch.2"
    @Published public var visibleSwitchIDs: Set<String> = []
    @Published public var visibleQuickActionIDs: Set<String> = []
    /// Anahtarların menüdeki sırası (kimlikler).
    @Published public var switchOrder: [String] = []
    /// Hızlı eylemlerin menüdeki sırası (kimlikler).
    @Published public var quickActionOrder: [String] = []
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
            var ids = Set(savedIDs)

            // Yeni sürümde eklenen anahtarları, kullanıcının daha önce
            // gizlediklerine dokunmadan görünür yap.
            let schema = defaults.integer(forKey: kSwitchSchemaVersion)
            if schema < 2 {
                ids.formUnion(PreferencesManager.schema2SwitchIDs)
            }
            if schema < 3 {
                ids.formUnion(PreferencesManager.schema3SwitchIDs)
            }
            if schema < 4 {
                ids.formUnion(PreferencesManager.schema4SwitchIDs)
            }
            if schema < 5 {
                ids.formUnion(PreferencesManager.schema5SwitchIDs)
            }
            if schema < currentSchemaVersion {
                defaults.set(currentSchemaVersion, forKey: kSwitchSchemaVersion)
                defaults.set(Array(ids), forKey: kVisibleSwitchIDs)
            }

            self.visibleSwitchIDs = ids
        } else {
            // İlk açılışta hepsi görünür
            self.visibleSwitchIDs = Set(PreferencesManager.allSwitchIDs)
            defaults.set(currentSchemaVersion, forKey: kSwitchSchemaVersion)
        }

        // Görünür hızlı eylemler (Varsayılan olarak tümü görünür)
        if let saved = defaults.array(forKey: kVisibleQuickActionIDs) as? [String] {
            var ids = Set(saved)
            // Yeni sürümde eklenen eylemleri, kullanıcının gizlediklerine
            // dokunmadan görünür yap.
            let schema = defaults.integer(forKey: kQuickActionSchemaVersion)
            if schema < 2 {
                ids.formUnion(PreferencesManager.schema2QuickActionIDs)
            }
            if schema < currentQuickActionSchemaVersion {
                defaults.set(currentQuickActionSchemaVersion, forKey: kQuickActionSchemaVersion)
                defaults.set(Array(ids), forKey: kVisibleQuickActionIDs)
            }
            self.visibleQuickActionIDs = ids
        } else {
            self.visibleQuickActionIDs = Set(QuickActionKind.allCases.map(\.rawValue))
            defaults.set(Array(self.visibleQuickActionIDs), forKey: kVisibleQuickActionIDs)
            defaults.set(currentQuickActionSchemaVersion, forKey: kQuickActionSchemaVersion)
        }

        // Sıralar: kayıtlı sıra korunur, yeni eklenenler sona eklenir.
        let savedSwitchOrder = defaults.array(forKey: kSwitchOrder) as? [String] ?? []
        self.switchOrder = PreferencesManager.normalizedOrder(
            saved: savedSwitchOrder,
            allIDs: PreferencesManager.allSwitchIDs
        )

        let savedActionOrder = defaults.array(forKey: kQuickActionOrder) as? [String] ?? []
        self.quickActionOrder = PreferencesManager.normalizedOrder(
            saved: savedActionOrder,
            allIDs: QuickActionKind.allCases.map(\.rawValue)
        )

        // Normalleştirilmiş sırayı yaz: yeni eklenen anahtarlar da sırada yer alsın.
        defaults.set(self.switchOrder, forKey: kSwitchOrder)
        defaults.set(self.quickActionOrder, forKey: kQuickActionOrder)
        
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

    /// Hızlı eylem görünürlüğünü açar/kapatır.
    public func setQuickActionVisible(_ id: String, visible: Bool) {
        if visible {
            visibleQuickActionIDs.insert(id)
        } else {
            visibleQuickActionIDs.remove(id)
        }
        defaults.set(Array(visibleQuickActionIDs), forKey: kVisibleQuickActionIDs)
    }

    public func isQuickActionVisible(id: String) -> Bool {
        return visibleQuickActionIDs.contains(id)
    }

    /// Menüde gösterilecek hızlı eylemler, kullanıcının sırasıyla.
    public var visibleQuickActions: [QuickActionKind] {
        allQuickActionsInOrder.filter { visibleQuickActionIDs.contains($0.rawValue) }
    }

    /// Tüm hızlı eylemler, kullanıcının sırasıyla (gizli olanlar dahil).
    /// Ayarlar ekranındaki sıralama listesi bunu kullanır.
    public var allQuickActionsInOrder: [QuickActionKind] {
        let byID = Dictionary(
            uniqueKeysWithValues: QuickActionKind.allCases.map { ($0.rawValue, $0) }
        )
        var ordered = quickActionOrder.compactMap { byID[$0] }
        let known = Set(quickActionOrder)
        ordered.append(contentsOf: QuickActionKind.allCases.filter { !known.contains($0.rawValue) })
        return ordered
    }

    /// Kayıtlı sırayı geçerli kimlik listesine göre düzenler:
    /// bilinmeyenleri atar, eksikleri sona ekler.
    private static func normalizedOrder(saved: [String], allIDs: [String]) -> [String] {
        let valid = Set(allIDs)
        var ordered = saved.filter { valid.contains($0) }
        let present = Set(ordered)
        ordered.append(contentsOf: allIDs.filter { !present.contains($0) })
        return ordered
    }

    // MARK: - Sıralama

    public func moveSwitch(fromOffsets source: IndexSet, toOffset destination: Int) {
        switchOrder = PreferencesManager.moved(
            switchOrder,
            fromOffsets: source,
            toOffset: destination
        )
        defaults.set(switchOrder, forKey: kSwitchOrder)
    }

    public func moveQuickAction(fromOffsets source: IndexSet, toOffset destination: Int) {
        quickActionOrder = PreferencesManager.moved(
            quickActionOrder,
            fromOffsets: source,
            toOffset: destination
        )
        defaults.set(quickActionOrder, forKey: kQuickActionOrder)
    }

    /// SwiftUI'nin `.onMove` semantiğiyle aynı taşıma.
    private static func moved(_ array: [String], fromOffsets source: IndexSet, toOffset destination: Int) -> [String] {
        var items = array
        let moving = source.map { items[$0] }
        // Önce yukarıdan aşağıya sil, IndexSet'i büyükten küçüğe işle.
        for index in source.sorted(by: >) where index < items.count {
            items.remove(at: index)
        }
        // Hedef, silmeden önceki dizine göreyim; kaç öğe hedefin önünde silindiyse o kadar düş.
        let removedBefore = source.filter { $0 < destination }.count
        let insertAt = min(max(destination - removedBefore, 0), items.count)
        items.insert(contentsOf: moving, at: insertAt)
        return items
    }

    /// Sırayı varsayılana döndürür.
    public func resetSwitchOrder() {
        switchOrder = PreferencesManager.allSwitchIDs
        defaults.set(switchOrder, forKey: kSwitchOrder)
    }

    public func resetQuickActionOrder() {
        quickActionOrder = QuickActionKind.allCases.map(\.rawValue)
        defaults.set(quickActionOrder, forKey: kQuickActionOrder)
    }

    /// Sıralamanın varsayılandan farklı olup olmadığı.
    public var isSwitchOrderCustom: Bool {
        switchOrder != PreferencesManager.allSwitchIDs
    }

    public var isQuickActionOrderCustom: Bool {
        quickActionOrder != QuickActionKind.allCases.map(\.rawValue)
    }
}

extension Notification.Name {
    public static let menuBarIconDidChange = Notification.Name("menuBarIconDidChange")
}
