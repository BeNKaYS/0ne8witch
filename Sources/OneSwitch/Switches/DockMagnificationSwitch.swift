import Foundation
import SwiftUI
import Combine

/// Dock ikonlarının fare üzerine gelince büyümesini sağlayan anahtar
public final class DockMagnificationSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "dock_magnify"
    public let title = "Dock Büyütme"
    public let iconName = "arrow.up.left.and.arrow.down.right"
    public let activeColor = Color.blue
    public let category = SwitchCategory.system
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Büyütme Kapalı"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        CommandRunner.shared.runShell("defaults write com.apple.dock magnification -bool \(value)")
        CommandRunner.shared.runShell("killall Dock")
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "DockMagnification")
        let on = (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "İkonlar Büyüyor" : "Büyütme Kapalı"
    }
}
