import Foundation
import SwiftUI
import Combine

/// Menü çubuğunu otomatik gizleyen anahtar
public final class MenuBarAutoHideSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "menubar_autohide"
    public let title = "Menü Çubuğunu Gizle"
    public let iconName = "menubar.rectangle"
    public let activeColor = Color.indigo
    public let category = SwitchCategory.display
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Menü Çubuğu Görünür"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        CommandRunner.shared.runShell("defaults write NSGlobalDomain _HIHideMenuBar -bool \(value)")
        // Menü çubuğunu yöneten süreç sürüme göre değişiyor; ikisi de denenir.
        CommandRunner.shared.runShell("killall ControlCenter 2>/dev/null || killall SystemUIServer 2>/dev/null")
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "MenuBarAutoHide")
        let on = (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "Menü Çubuğu Gizli" : "Menü Çubuğu Görünür"
    }
}
