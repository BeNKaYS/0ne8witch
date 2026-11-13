import Foundation
import SwiftUI
import Combine

/// Uykudan veya ekran koruyucudan çıkarken parola istenmesini sağlayan anahtar
public final class AskPasswordSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "ask_password"
    public let title = "Uyanınca Şifre İste"
    public let iconName = "lock.shield.fill"
    public let activeColor = Color.green
    public let category = SwitchCategory.system
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Şifre İstenmiyor"

    public init() {
        refresh()
    }

    public func toggle() {
        let value = !isOn
        let intVal = value ? "1" : "0"
        // Ayar hem kullanıcı hem de host bazlı okunabildiği için ikisine de yazılır.
        CommandRunner.shared.runShell("""
        defaults -currentHost write com.apple.screensaver askForPassword -int \(intVal)
        defaults write com.apple.screensaver askForPassword -int \(intVal)
        if [ "\(intVal)" = "1" ]; then
            defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0
            defaults write com.apple.screensaver askForPasswordDelay -int 0
        fi
        """)
        SystemStateReader.shared.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "AskPassword")
        let on = (val == "1" || val.lowercased() == "true")
        self.isOn = on
        self.subtitle = on ? "Uyanınca Şifre Sorulur" : "Şifre İstenmiyor"
    }
}
