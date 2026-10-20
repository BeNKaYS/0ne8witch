import Foundation
import SwiftUI
import Combine

/// macOS Ventura ve sonrası için Sahne Yöneticisi (Stage Manager) anahtarı
public final class StageManagerSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "stage_manager"
    public let title = "Sahne Yöneticisi"
    public let iconName = "rectangle.split.2x1.fill"
    public let activeColor = Color.cyan
    public let category = SwitchCategory.system
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Kapalı"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let boolVal = newState ? "true" : "false"
        let cmd = "defaults write com.apple.WindowManager GloballyEnabled -bool \(boolVal)"
        CommandRunner.shared.runShell(cmd)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let val = SystemStateReader.shared.value(for: "WindowManagerGloballyEnabled")
        let active = (val == "1" || val.lowercased() == "true")
        self.isOn = active
        self.subtitle = active ? "Sahne Yöneticisi Açık" : "Kapalı"
    }
}
