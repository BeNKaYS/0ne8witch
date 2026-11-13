import Foundation

/// Menüdeki "Hızlı Eylemler & Araçlar" bölümündeki tek tıkla çalışan eylemler.
///
/// Her eylem kendi kimliğiyle tanımlanır; hangilerinin görüneceği
/// `PreferencesManager.visibleQuickActionIDs` içinde tutulur.
public enum QuickActionKind: String, CaseIterable, Identifiable {
    case emptyTrash = "empty_trash"
    case killPorts = "kill_ports"
    case ejectDisks = "eject_disks"
    case purgeMemory = "purge_memory"
    case clearPasteboard = "clear_pasteboard"
    case lockScreen = "lock_screen"
    case screenSaver = "screen_saver"
    case sleepDisplay = "sleep_display"
    case pickColor = "pick_color"
    case cleanXcode = "clean_xcode"
    case addDockSpacer = "add_dock_spacer"
    case removeDockSpacers = "remove_dock_spacers"
    case repairApp = "repair_app"
    case copyIP = "copy_ip"
    case ipOverview = "ip_overview"
    case systemStatus = "system_status"
    case xcodeCleanFull = "xcode_clean_full"
    case shortcuts = "shortcuts"
    case systemPower = "system_power"
    case softRestart = "soft_restart"

    public var id: String { rawValue }

    /// Buton etiketi (dar sütunlara sığacak kadar kısa).
    public var label: String {
        switch self {
        case .emptyTrash: return "Çöpü Boşalt"
        case .killPorts: return "Port Temizle"
        case .ejectDisks: return "Diskleri Çıkar"
        case .purgeMemory: return "RAM Temizle"
        case .clearPasteboard: return "Panoyu Sil"
        case .lockScreen: return "Ekranı Kilitle"
        case .screenSaver: return "Ekran Koruyucu"
        case .sleepDisplay: return "Ekranı Uyut"
        case .pickColor: return "Renk Seç"
        case .cleanXcode: return "Xcode Temizle"
        case .addDockSpacer: return "Dock Ayracı"
        case .removeDockSpacers: return "Ayraçları Sil"
        case .repairApp: return "Uygulama Onar"
        case .copyIP: return "IP Kopyala"
        case .ipOverview: return "IP & Ağ"
        case .systemStatus: return "Sistem Durumu"
        case .xcodeCleanFull: return "Xcode Temizle"
        case .shortcuts: return "Kısayollar"
        case .systemPower: return "Güç"
        case .softRestart: return "Servisleri Yenile"
        }
    }

    /// Ayarlar ekranında görünen uzun açıklama.
    public var detail: String {
        switch self {
        case .emptyTrash: return "Çöp kutusunu uyarı penceresi göstermeden boşaltır."
        case .killPorts: return "3000, 5000, 8000, 8080, 8888 portlarını tutan süreçleri sonlandırır."
        case .ejectDisks: return "Takılı harici diskleri ve USB bellekleri güvenle çıkarır."
        case .purgeMemory: return "Bellek önbelleğini temizler (yönetici izni gerekebilir)."
        case .clearPasteboard: return "Panodaki metin ve görselleri siler."
        case .lockScreen: return "Ekranı hemen kilitler."
        case .screenSaver: return "Ekran koruyucuyu başlatır."
        case .sleepDisplay: return "Ekranı uyku moduna geçirir."
        case .pickColor: return "Ekrandan renk seçip HEX kodunu panoya kopyalar."
        case .cleanXcode: return "Xcode DerivedData önbelleğini temizler."
        case .addDockSpacer: return "Dock'a grup ayracı (boşluk) ekler."
        case .removeDockSpacers: return "Dock'taki tüm ayraçları kaldırır."
        case .repairApp: return "Açılmayan uygulamanın karantina niteliğini kaldırır."
        case .copyIP: return "Yerel ve dış IP adresini panoya kopyalar."
        case .ipOverview: return "Yerel/dış IP, konum, gecikme ve paket kaybını gösterir."
        case .systemStatus: return "İşlemci, bellek, disk, ağ ve pil durumunu canlı gösterir."
        case .xcodeCleanFull: return "DerivedData, cihaz desteği, arşiv ve önbellekleri temizler."
        case .shortcuts: return "Kurulu Kısayolları listeler ve çalıştırır."
        case .systemPower: return "Uyku, oturum kapatma, yeniden başlatma ve kapatma."
        case .softRestart: return "Finder, Dock ve menü çubuğu servislerini yeniler."
        }
    }

    public var icon: String {
        switch self {
        case .emptyTrash: return "trash"
        case .killPorts: return "network"
        case .ejectDisks: return "eject.fill"
        case .purgeMemory: return "memorychip"
        case .clearPasteboard: return "doc.on.clipboard"
        case .lockScreen: return "lock.fill"
        case .screenSaver: return "sparkles"
        case .sleepDisplay: return "moon.fill"
        case .pickColor: return "eyedropper.halffull"
        case .cleanXcode: return "hammer.fill"
        case .addDockSpacer: return "plus.rectangle"
        case .removeDockSpacers: return "trash.slash"
        case .repairApp: return "cross.case.fill"
        case .copyIP: return "network.badge.shield.half.filled"
        case .ipOverview: return "globe"
        case .systemStatus: return "speedometer"
        case .xcodeCleanFull: return "trash.slash.fill"
        case .shortcuts: return "square.stack.3d.up.fill"
        case .systemPower: return "power"
        case .softRestart: return "arrow.triangle.2.circlepath"
        }
    }

    /// Eylemi çalıştırır. Tamamlanan eylemler menüde kısa bildirim gösterir.
    @MainActor
    public func perform() {
        let notify: (String) -> Void = { message in
            SwitchManager.shared.showNotification(message)
        }

        switch self {
        case .emptyTrash:
            QuickActions.shared.emptyTrash(completion: notify)
        case .killPorts:
            QuickActions.shared.killDevPorts(completion: notify)
        case .ejectDisks:
            QuickActions.shared.ejectAllDisks(completion: notify)
        case .purgeMemory:
            QuickActions.shared.purgeMemory(completion: notify)
        case .clearPasteboard:
            QuickActions.shared.clearPasteboard()
            notify("Pano temizlendi.")
        case .lockScreen:
            QuickActions.shared.lockScreen()
        case .screenSaver:
            QuickActions.shared.startScreenSaver()
        case .sleepDisplay:
            QuickActions.shared.sleepDisplay()
        case .pickColor:
            QuickActions.shared.pickColor(completion: notify)
        case .cleanXcode:
            QuickActions.shared.cleanXcodeDerivedData(completion: notify)
        case .addDockSpacer:
            QuickActions.shared.addDockSpacer(completion: notify)
        case .removeDockSpacers:
            QuickActions.shared.removeDockSpacers(completion: notify)
        case .repairApp:
            QuickActions.shared.repairDamagedApp(completion: notify)
        case .copyIP:
            QuickActions.shared.copyIPAddresses(completion: notify)
        case .ipOverview:
            PanelWindow.shared.show(
                id: "ip_overview",
                title: "IP & Ağ Durumu",
                width: 380,
                height: 400
            ) { IPOverviewPanel() }
        case .systemStatus:
            PanelWindow.shared.show(
                id: "system_status",
                title: "Sistem Durumu",
                width: 380,
                height: 430
            ) { SystemStatusPanel() }
        case .xcodeCleanFull:
            PanelWindow.shared.show(
                id: "xcode_clean",
                title: "Xcode Derin Temizlik",
                width: 420,
                height: 470
            ) { XcodeCleanPanel() }
        case .shortcuts:
            PanelWindow.shared.show(
                id: "shortcuts",
                title: "Kısayollar",
                width: 380,
                height: 470
            ) { ShortcutsPanel() }
        case .systemPower:
            QuickActions.shared.showPowerMenu(completion: notify)
        case .softRestart:
            QuickActions.shared.softRestart(completion: notify)
        }
    }
}
