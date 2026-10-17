import Foundation
import SwiftUI
import Combine

/// Finder'da dosya uzantılarını (.png, .pdf vb.) her zaman gösteren veya gizleyen anahtar
public final class FileExtensionsSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "file_extensions"
    public let title = "Dosya Uzantılarını Göster"
    public let iconName = "doc.badge.gearshape.fill"
    public let activeColor = Color.blue
    public let category = SwitchCategory.display
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Uzantılar Saklı"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let boolVal = newState ? "true" : "false"
        let cmd = "defaults write NSGlobalDomain AppleShowAllExtensions -bool \(boolVal) && killall Finder"
        CommandRunner.shared.runShell(cmd)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let result = CommandRunner.shared.runShell("defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null")
        let val = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let isShowing = (val == "1" || val.lowercased() == "true")
        self.isOn = isShowing
        self.subtitle = isShowing ? "Uzantılar Görünür" : "Uzantılar Saklı"
    }
}
