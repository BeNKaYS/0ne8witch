import Foundation
import SwiftUI
import Combine

/// macOS Karanlık / Aydınlık Modunu değiştiren anahtar
public final class DarkModeSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "dark_mode"
    public let title = "Karanlık Mod"
    public let iconName = "moon.stars.fill"
    public let activeColor = Color.indigo
    public let category = SwitchCategory.display
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Aydınlık Mod"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        CommandRunner.shared.runAppleScript(script)
        
        // Durumu anında yenile
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let isDark = SystemStateReader.shared.value(for: "AppleInterfaceStyle").lowercased() == "dark"
        self.isOn = isDark
        self.subtitle = isDark ? "Karanlık Tema Açık" : "Aydınlık Tema Açık"
    }
}
