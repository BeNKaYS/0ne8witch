import Foundation
import SwiftUI
import Combine

/// Tek bir `defaults` anahtarını açıp kapatan genel anahtar.
///
/// Durum `SystemStateReader` önbelleğinden (`stateKey`) okunur; yazarken
/// ilgili servis (`restart`) yeniden başlatılır ki değişiklik hemen görünsün.
public final class DefaultsSwitch: ObservableObject, SwitchItemProtocol {
    public let id: String
    public let title: String
    public let iconName: String
    public let activeColor = Color.orange
    public let category: SwitchCategory
    public let hasOptions = false

    private let domain: String
    private let key: String
    private let stateKey: String
    private let restart: String
    private let onText: String
    private let offText: String

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = ""

    public init(
        id: String, title: String, icon: String, category: SwitchCategory,
        domain: String, key: String, stateKey: String,
        restart: String, onText: String, offText: String
    ) {
        self.id = id
        self.title = title
        self.iconName = icon
        self.category = category
        self.domain = domain
        self.key = key
        self.stateKey = stateKey
        self.restart = restart
        self.onText = onText
        self.offText = offText
        refresh()
    }

    public func toggle() {
        CommandRunner.shared.runShell(
            "defaults write \(domain) \(key) -bool \(!isOn) && killall \(restart) 2>/dev/null"
        )
        SystemStateReader.shared.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let raw = SystemStateReader.shared.value(for: stateKey).lowercased()
        isOn = (raw == "1" || raw == "true")
        subtitle = isOn ? onText : offText
    }
}

extension DefaultsSwitch {
    /// Ekran görüntülerinde pencere gölgesini kaldırır.
    static func screenshotShadow() -> DefaultsSwitch {
        DefaultsSwitch(
            id: "screenshot_no_shadow", title: "Gölgesiz Ekran Görüntüsü",
            icon: "camera.viewfinder", category: .display,
            domain: "com.apple.screencapture", key: "disable-shadow", stateKey: "ScreenshotShadow",
            restart: "SystemUIServer",
            onText: "Pencere Gölgesi Yok", offText: "Pencere Gölgesi Var"
        )
    }

    /// Gizlenen (⌘H) uygulamaları Dock'ta yarı saydam gösterir.
    static func dockShowHidden() -> DefaultsSwitch {
        DefaultsSwitch(
            id: "dock_show_hidden", title: "Gizlenenler Dock'ta Soluk",
            icon: "eye.slash", category: .system,
            domain: "com.apple.dock", key: "showhidden", stateKey: "DockShowHidden",
            restart: "Dock",
            onText: "Gizlenen Uygulamalar Soluk", offText: "Standart Görünüm"
        )
    }

    /// Dock'ta yalnızca açık uygulamaları gösterir.
    static func dockStaticOnly() -> DefaultsSwitch {
        DefaultsSwitch(
            id: "dock_static_only", title: "Dock'ta Yalnızca Açıklar",
            icon: "dock.rectangle", category: .system,
            domain: "com.apple.dock", key: "static-only", stateKey: "DockStaticOnly",
            restart: "Dock",
            onText: "Sabitlenenler Gizli", offText: "Tüm Uygulamalar"
        )
    }

    /// Finder'da klasörleri dosyalardan önce sıralar.
    static func finderFoldersFirst() -> DefaultsSwitch {
        DefaultsSwitch(
            id: "finder_folders_first", title: "Klasörler Önce",
            icon: "folder.fill", category: .utility,
            domain: "com.apple.finder", key: "_FXSortFoldersFirst", stateKey: "FinderFoldersFirst",
            restart: "Finder",
            onText: "Klasörler Üstte", offText: "Karışık Sıralama"
        )
    }

    /// Finder menüsüne "Finder'dan Çık" (⌘Q) ekler.
    static func quitFinder() -> DefaultsSwitch {
        DefaultsSwitch(
            id: "finder_quit", title: "Finder'dan Çıkılabilsin",
            icon: "xmark.app", category: .utility,
            domain: "com.apple.finder", key: "QuitMenuItem", stateKey: "QuitFinder",
            restart: "Finder",
            onText: "⌘Q Etkin", offText: "Finder Hep Açık"
        )
    }
}
