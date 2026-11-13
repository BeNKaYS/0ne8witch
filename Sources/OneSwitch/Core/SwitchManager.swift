import Foundation
import SwiftUI
import Combine

/// Tüm anahtarları ve durumlarını yöneten merkezi sınıf
public final class SwitchManager: ObservableObject {
    public static let shared = SwitchManager()
    
    // Anahtar Örnekleri
    public let keepAwake = KeepAwakeSwitch()
    public let darkMode = DarkModeSwitch()
    public let desktopIcons = DesktopIconsSwitch()
    public let hiddenFiles = HiddenFilesSwitch()
    public let fileExtensions = FileExtensionsSwitch()
    public let userLibrary = UserLibrarySwitch()
    public let microphoneMute = MicrophoneMuteSwitch()
    public let stageManager = StageManagerSwitch()
    public let hideWidgets = HideWidgetsSwitch()
    public let dockAutoHide = DockAutoHideSwitch()
    public let screenClean = ScreenCleanSwitch()
    public let lowPowerMode = LowPowerModeSwitch()
    public let naturalScroll = NaturalScrollSwitch()
    public let presentationMode = PresentationModeSwitch()
    public let finderPathbar = FinderPathbarSwitch()
    public let finderStatusBar = FinderStatusBarSwitch()
    public let menuBarAutoHide = MenuBarAutoHideSwitch()
    public let clockSeconds = ClockSecondsSwitch()
    public let dockMagnification = DockMagnificationSwitch()
    public let dockRecents = DockRecentsSwitch()
    public let askPassword = AskPasswordSwitch()
    public let wifi = WiFiSwitch()
    public let bluetooth = BluetoothSwitch()
    public let nightShift = NightShiftSwitch()
    public let focus = FocusSwitch()
    public let airPods = AirPodsSwitch()
    public let trueTone = TrueToneSwitch()
    public let brightness = BrightnessSwitch()
    public let hideNotch = HideNotchSwitch()
    public let systemMute = SystemMuteSwitch()
    public let screenshotShadow = DefaultsSwitch.screenshotShadow()
    public let dockShowHidden = DefaultsSwitch.dockShowHidden()
    public let dockStaticOnly = DefaultsSwitch.dockStaticOnly()
    public let finderFoldersFirst = DefaultsSwitch.finderFoldersFirst()
    public let quitFinder = DefaultsSwitch.quitFinder()
    
    @Published public var statusNotification: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    /// Toplu yenileme sırasında ara UI güncellemelerini engeller.
    private var isBatchRefreshing = false
    
    private func relayChange() {
        guard !isBatchRefreshing else { return }
        objectWillChange.send()
    }
    
    private init() {
        // Alt anahtarlardaki değişiklikleri dinleyip UI'ı güncelle
        for item in baseSwitches {
            if let observable = item as? any ObservableObject {
                observe(observable)
            }
        }
        observe(PreferencesManager.shared)
    }

    private func observe<T: ObservableObject>(_ object: T) {
        object.objectWillChange
            .sink { [weak self] _ in self?.relayChange() }
            .store(in: &cancellables)
    }
    
    /// Tüm anahtarları dizi olarak döndürür.
    /// Sıra, kullanıcının Ayarlar ekranında belirlediği sıradır.
    public var allSwitches: [any SwitchItemProtocol] {
        let items = baseSwitches

        let order = PreferencesManager.shared.switchOrder
        guard !order.isEmpty else { return items }

        var byID: [String: any SwitchItemProtocol] = [:]
        for item in items { byID[item.id] = item }

        var ordered: [any SwitchItemProtocol] = []
        ordered.reserveCapacity(items.count)
        var placed = Set<String>()
        for id in order {
            if let item = byID[id], placed.insert(id).inserted {
                ordered.append(item)
            }
        }
        // Sırada olmayan (yeni eklenmiş) anahtarlar sona eklenir.
        ordered.append(contentsOf: items.filter { !placed.contains($0.id) })
        return ordered
    }

    /// Varsayılan sıradaki tüm anahtarlar.
    private var baseSwitches: [any SwitchItemProtocol] {
        [
            presentationMode,
            keepAwake,
            darkMode,
            desktopIcons,
            hiddenFiles,
            fileExtensions,
            userLibrary,
            microphoneMute,
            stageManager,
            hideWidgets,
            dockAutoHide,
            screenClean,
            lowPowerMode,
            naturalScroll,
            finderPathbar,
            finderStatusBar,
            menuBarAutoHide,
            clockSeconds,
            dockMagnification,
            dockRecents,
            askPassword,
            wifi,
            bluetooth,
            nightShift,
            focus,
            airPods,
            trueTone,
            brightness,
            hideNotch,
            systemMute,
            screenshotShadow,
            dockShowHidden,
            dockStaticOnly,
            finderFoldersFirst,
            quitFinder
        ]
    }

    /// Kullanıcı görünürlük tercihlerine göre filtrelenmiş anahtarlar
    public var filteredSwitches: [any SwitchItemProtocol] {
        return allSwitches.filter { item in
            PreferencesManager.shared.isSwitchVisible(id: item.id)
        }
    }
    
    /// Menü açıldığında tüm anahtarların durumunu günceller.
    /// Tüm okumalar tek bir sistem çağrısını paylaşır.
    public func refreshAll() {
        isBatchRefreshing = true
        allSwitches.forEach { $0.refresh() }
        isBatchRefreshing = false
        objectWillChange.send()
    }
    
    /// Kısa süreli bilgilendirme mesajı gösterir
    public func showNotification(_ message: String) {
        self.statusNotification = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.statusNotification == message {
                self?.statusNotification = nil
            }
        }
    }
}
