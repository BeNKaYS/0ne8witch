import Foundation
import SwiftUI
import Combine

/// Finder'daki gizli dosyaları (nokta ile başlayanları) gösteren/gizleyen anahtar
public final class HiddenFilesSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "hidden_files"
    public let title = "Gizli Dosyaları Göster"
    public let iconName = "eye.trianglebadge.exclamationmark"
    public let activeColor = Color.purple
    public let category = SwitchCategory.display
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Gizli Dosyalar Saklı"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let boolVal = newState ? "true" : "false"
        let cmd = "defaults write com.apple.finder AppleShowAllFiles -bool \(boolVal) && killall Finder"
        CommandRunner.shared.runShell(cmd)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let val = SystemStateReader.shared.value(for: "FinderShowAllFiles")
        let isShowing = (val == "1" || val.lowercased() == "true")
        self.isOn = isShowing
        self.subtitle = isShowing ? "Gizli Dosyalar Görünür" : "Gizli Dosyalar Saklı"
    }
}
