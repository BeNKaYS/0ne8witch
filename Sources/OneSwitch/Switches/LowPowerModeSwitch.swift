import Foundation
import SwiftUI
import Combine

/// Mac'in pil tasarrufu için Düşük Güç Modunu kontrol eden anahtar
public final class LowPowerModeSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "low_power_mode"
    public let title = "Düşük Güç Modu"
    public let iconName = "battery.25"
    public let activeColor = Color.green
    public let category = SwitchCategory.system
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Standart Performans"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let mode = newState ? "1" : "0"
        let script = "do shell script \"pmset -a lowpowermode \(mode)\" with administrator privileges"
        let res = CommandRunner.shared.runAppleScript(script)
        
        if res.success {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.refresh()
            }
        } else {
            // Eğer yönetici şifresi iptal edildiyse durumu yenile
            refresh()
        }
    }
    
    public func refresh() {
        let res = CommandRunner.shared.runShell("pmset -g 2>/dev/null | grep lowpowermode")
        let isEnabled = res.output.contains("1")
        self.isOn = isEnabled
        self.subtitle = isEnabled ? "Pil Tasarrufu Etkin" : "Standart Performans"
    }
}
