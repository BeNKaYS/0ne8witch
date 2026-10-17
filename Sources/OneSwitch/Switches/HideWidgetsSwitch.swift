import Foundation
import SwiftUI
import Combine

/// macOS Sonoma ve sonrası için Masaüstü Widget'larını Gizleyen anahtar
public final class HideWidgetsSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "hide_widgets"
    public let title = "Masaüstü Araç Takımlarını Gizle"
    public let iconName = "square.stack.3d.down.right.fill"
    public let activeColor = Color.teal
    public let category = SwitchCategory.display
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Araç Takımları Görünür"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let boolVal = newState ? "true" : "false"
        let cmd = "defaults write com.apple.WindowManager StandardHideWidgets -bool \(boolVal)"
        CommandRunner.shared.runShell(cmd)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let result = CommandRunner.shared.runShell("defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null")
        let val = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let isHidden = (val == "1" || val.lowercased() == "true")
        self.isOn = isHidden
        self.subtitle = isHidden ? "Araç Takımları Gizli" : "Araç Takımları Masaüstünde"
    }
}
