import Foundation
import SwiftUI
import Combine

/// Dock'un otomatik gizlenmesini kontrol eden anahtar
public final class DockAutoHideSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "dock_autohide"
    public let title = "Dock'u Otomatik Gizle"
    public let iconName = "menubar.dock.rectangle"
    public let activeColor = Color.mint
    public let category = SwitchCategory.system
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Dock Sabit"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let script = "tell application \"System Events\" to tell dock preferences to set autohide to not autohide"
        CommandRunner.shared.runAppleScript(script)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let script = "tell application \"System Events\" to tell dock preferences to get autohide"
        let res = CommandRunner.shared.runAppleScript(script)
        let isAuto = res.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "true"
        self.isOn = isAuto
        self.subtitle = isAuto ? "Dock Otomatik Gizleniyor" : "Dock Her Zaman Görünür"
    }
}
