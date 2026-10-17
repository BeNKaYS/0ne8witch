import Foundation
import SwiftUI
import Combine

/// Eğitmenler ve sunum yapanlar için tek tıkla masaüstünü temizleyen, widget'ları gizleyen ve uyku modunu engelleyen Sunum/Ders Modu
public final class PresentationModeSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "presentation_mode"
    public let title = "Ders & Sunum Modu"
    public let iconName = "person.wave.2.fill"
    public let activeColor = Color.purple
    public let category = SwitchCategory.utility
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Sunum Hazırlığı Kapalı"
    
    public init() {}
    
    public func toggle() {
        if isOn {
            // Sunum modunu kapat: Masaüstünü ve widget'ları geri getir, uykuyu serbest bırak
            CommandRunner.shared.runShell("defaults write com.apple.finder CreateDesktop -bool true && killall Finder")
            CommandRunner.shared.runShell("defaults write com.apple.WindowManager StandardHideWidgets -bool false")
            SwitchManager.shared.keepAwake.turnOff()
            
            self.isOn = false
            self.subtitle = "Sunum Hazırlığı Kapalı"
        } else {
            // Sunum modunu aç: Masaüstünü temizle, widget'ları sakla, uykuyu engelle
            CommandRunner.shared.runShell("defaults write com.apple.finder CreateDesktop -bool false && killall Finder")
            CommandRunner.shared.runShell("defaults write com.apple.WindowManager StandardHideWidgets -bool true")
            SwitchManager.shared.keepAwake.turnOn(duration: .indefinite)
            
            self.isOn = true
            self.subtitle = "Masaüstü Temiz & Uyanık (Ders/Sunum Aktif)"
        }
        
        // Diğer anahtarları da güncellemeleri için tetikle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            SwitchManager.shared.desktopIcons.refresh()
            SwitchManager.shared.hideWidgets.refresh()
        }
    }
    
    public func refresh() {
        // Masaüstü simgeleri gizli ve KeepAwake açıksa sunum modu aktiftir
        let desktopRes = CommandRunner.shared.runShell("defaults read com.apple.finder CreateDesktop 2>/dev/null")
        let desktopHidden = (desktopRes.output.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
        let isAwake = SwitchManager.shared.keepAwake.isOn
        
        if desktopHidden && isAwake {
            self.isOn = true
            self.subtitle = "Masaüstü Temiz & Uyanık"
        } else if isOn {
            self.isOn = false
            self.subtitle = "Sunum Hazırlığı Kapalı"
        }
    }
}
