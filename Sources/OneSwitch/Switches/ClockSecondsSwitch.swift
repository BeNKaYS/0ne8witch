import Foundation
import SwiftUI
import Combine

/// Menü çubuğundaki saatte saniyeleri gösteren anahtar
public final class ClockSecondsSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "clock_seconds"
    public let title = "Saatte Saniyeler"
    public let iconName = "clock.fill"
    public let activeColor = Color.orange
    public let category = SwitchCategory.display
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Saniyeler Gizli"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        CommandRunner.shared.runShell("defaults write com.apple.menuextra.clock ShowSeconds -bool \(value)")
        CommandRunner.shared.runShell("killall ControlCenter 2>/dev/null || killall SystemUIServer 2>/dev/null")
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "ClockSeconds")
        let on = (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "Saniyeler Görünür" : "Saniyeler Gizli"
    }
}
