import Foundation
import SwiftUI
import Combine

/// Dock'un sağındaki "son kullanılan uygulamalar" bölümünü yöneten anahtar
public final class DockRecentsSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "dock_recents"
    public let title = "Dock Son Uygulamalar"
    public let iconName = "clock.arrow.circlepath"
    public let activeColor = Color.purple
    public let category = SwitchCategory.system
    public let hasOptions = false

    /// true: son uygulamalar görünür
    @Published public var isOn: Bool = true
    @Published public var subtitle: String = "Son Uygulamalar Görünür"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        CommandRunner.shared.runShell("defaults write com.apple.dock show-recents -bool \(value)")
        CommandRunner.shared.runShell("killall Dock")
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "DockRecents")
        // Tanımsızsa macOS varsayılanı açıktır.
        let on = val.isEmpty ? true : (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "Son Uygulamalar Görünür" : "Son Uygulamalar Gizli"
    }
}
