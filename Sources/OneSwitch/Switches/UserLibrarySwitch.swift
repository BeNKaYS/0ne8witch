import Foundation
import SwiftUI
import Combine

/// macOS'ta varsayılan olarak gizli olan ~/Library (Kitaplık) klasörünü gösteren/gizleyen anahtar
public final class UserLibrarySwitch: ObservableObject, SwitchItemProtocol {
    public let id = "user_library"
    public let title = "Kitaplık Klasörünü Göster"
    public let iconName = "folder.badge.gearshape"
    public let activeColor = Color.orange
    public let category = SwitchCategory.utility
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "~/Library Saklı"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let path = NSString(string: "~/Library").expandingTildeInPath
        if isOn {
            CommandRunner.shared.runShell("chflags hidden \"\(path)\"")
            self.isOn = false
            self.subtitle = "~/Library Saklı"
        } else {
            CommandRunner.shared.runShell("chflags nohidden \"\(path)\"")
            self.isOn = true
            self.subtitle = "~/Library Görünür"
        }
    }
    
    public func refresh() {
        let isHidden = SystemStateReader.shared.value(for: "UserLibrary").contains("hidden")
        self.isOn = !isHidden
        self.subtitle = isHidden ? "~/Library Saklı" : "~/Library Görünür"
    }
}
