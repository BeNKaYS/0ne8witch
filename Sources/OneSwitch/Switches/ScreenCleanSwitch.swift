import Foundation
import SwiftUI
import Combine

/// Ekran ve klavye temizliği için karartma penceresini açan anahtar
public final class ScreenCleanSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "screen_clean"
    public let title = "Ekran Temizleme Modu"
    public let iconName = "sparkles"
    public let activeColor = Color.yellow
    public let category = SwitchCategory.utility
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Temizlik İçin Hazır"
    
    private var overlayWindow: ScreenCleanOverlayWindow?
    
    public init() {}
    
    public func toggle() {
        if isOn {
            overlayWindow?.orderOut(nil)
            overlayWindow = nil
            self.isOn = false
            self.subtitle = "Temizlik Kapalı"
        } else {
            let window = ScreenCleanOverlayWindow()
            window.onDismiss = { [weak self] in
                self?.isOn = false
                self?.subtitle = "Temizlik Kapalı"
                self?.overlayWindow = nil
            }
            window.makeKeyAndOrderFront(nil)
            self.overlayWindow = window
            self.isOn = true
            self.subtitle = "Ekran Karartıldı (Çıkış: ESC)"
        }
    }
    
    public func refresh() {
        if overlayWindow == nil {
            self.isOn = false
            self.subtitle = "Temizlik İçin Hazır"
        }
    }
}
