import Foundation
import SwiftUI
import Combine

/// Masaüstündeki simgeleri anında gizleyen veya gösteren anahtar
public final class DesktopIconsSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "desktop_icons"
    public let title = "Masaüstü Simgelerini Gizle"
    public let iconName = "macwindow"
    public let activeColor = Color.blue
    public let category = SwitchCategory.display
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Simgeler Görünür"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let boolVal = newState ? "false" : "true"
        let cmd = "defaults write com.apple.finder CreateDesktop -bool \(boolVal) && killall Finder"
        CommandRunner.shared.runShell(cmd)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let val = SystemStateReader.shared.value(for: "FinderCreateDesktop")
        // Eğer 0 veya false ise gizli (yani switch açık) demektir
        let isHidden = (val == "0" || val.lowercased() == "false")
        self.isOn = isHidden
        self.subtitle = isHidden ? "Masaüstü Temiz & Gizli" : "Simgeler Masaüstünde"
    }
}
