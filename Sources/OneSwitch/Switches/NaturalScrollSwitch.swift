import Foundation
import SwiftUI
import Combine

/// Fare ve izleme dörtgeni (trackpad) için Doğal Kaydırma yönünü değiştiren anahtar
public final class NaturalScrollSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "natural_scroll"
    public let title = "Doğal Kaydırma"
    public let iconName = "arrow.up.and.down.circle.fill"
    public let activeColor = Color.indigo
    public let category = SwitchCategory.system
    public let hasOptions = false
    
    @Published public var isOn: Bool = true
    @Published public var subtitle: String = "Doğal Yön Açık"
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        let newState = !isOn
        let boolVal = newState ? "true" : "false"
        let cmd = "defaults write NSGlobalDomain com.apple.swipescrolldirection -bool \(boolVal)"
        CommandRunner.shared.runShell(cmd)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
        }
    }
    
    public func refresh() {
        let val = SystemStateReader.shared.value(for: "ScrollDirection")
        let isNatural = (val == "1" || val.lowercased() == "true")
        self.isOn = isNatural
        self.subtitle = isNatural ? "Doğal Kaydırma Açık" : "Klasik Kaydırma (Ters)"
    }
}
