import Foundation
import SwiftUI
import Combine

/// Finder pencerelerinin altında öğe sayısı ve disk alanını gösteren anahtar
public final class FinderStatusBarSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "finder_statusbar"
    public let title = "Finder Durum Çubuğu"
    public let iconName = "info.square.fill"
    public let activeColor = Color.teal
    public let category = SwitchCategory.display
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Durum Çubuğu Kapalı"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        CommandRunner.shared.runShell("defaults write com.apple.finder ShowStatusBar -bool \(value)")
        CommandRunner.shared.runShell("killall Finder")
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "FinderStatusBar")
        let on = (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "Öğe Sayısı Görünür" : "Durum Çubuğu Kapalı"
    }
}
