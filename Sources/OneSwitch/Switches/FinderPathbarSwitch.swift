import Foundation
import SwiftUI
import Combine

/// Finder pencerelerinin altında klasör yolunu gösteren anahtar
public final class FinderPathbarSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "finder_pathbar"
    public let title = "Finder Yol Çubuğu"
    public let iconName = "arrow.right.square.fill"
    public let activeColor = Color.blue
    public let category = SwitchCategory.display
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Yol Çubuğu Kapalı"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        CommandRunner.shared.runShell("defaults write com.apple.finder ShowPathbar -bool \(value)")
        CommandRunner.shared.runShell("killall Finder")
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "FinderPathbar")
        let on = (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "Klasör Yolu Görünür" : "Yol Çubuğu Kapalı"
    }
}
