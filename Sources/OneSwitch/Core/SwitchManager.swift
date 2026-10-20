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
    
    @Published public var selectedCategory: SwitchCategory = .all
    @Published public var searchText: String = ""
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
        keepAwake.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        darkMode.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        desktopIcons.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        hiddenFiles.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        fileExtensions.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        userLibrary.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        microphoneMute.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        stageManager.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        hideWidgets.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        dockAutoHide.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        screenClean.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        lowPowerMode.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        naturalScroll.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        presentationMode.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
        PreferencesManager.shared.objectWillChange.sink { [weak self] _ in self?.relayChange() }.store(in: &cancellables)
    }
    
    /// Tüm anahtarları dizi olarak döndürür
    public var allSwitches: [any SwitchItemProtocol] {
        return [
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
            naturalScroll
        ]
    }
    
    /// Arama, kategori ve kullanıcı görünürlük tercihlerine göre filtrelenmiş anahtarlar
    public var filteredSwitches: [any SwitchItemProtocol] {
        return allSwitches.filter { item in
            let isVisible = PreferencesManager.shared.isSwitchVisible(id: item.id)
            let matchesCategory = (selectedCategory == .all || item.category == selectedCategory)
            let matchesSearch = searchText.isEmpty ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.subtitle.localizedCaseInsensitiveContains(searchText)
            return isVisible && matchesCategory && matchesSearch
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
