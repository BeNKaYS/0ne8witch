import Foundation
import SwiftUI
import Combine

/// Rahatsız Etme / Odaklanma modunu Kısayollar üzerinden değiştiren anahtar.
///
/// Apple, macOS 11'den beri Odaklanma durumunu değiştiren herkese açık bir API
/// sunmuyor. Kullanıcı Kısayollar uygulamasında bir "Odak Ayarla" kısayolu
/// oluşturur; bu anahtar onu çalıştırır.
public final class FocusSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "dnd"
    public let title = "Rahatsız Etme"
    public let iconName = "moon.zzz.fill"
    public let activeColor = Color.purple
    public let category = SwitchCategory.system
    public let hasOptions = false

    /// Kullanıcının Kısayollar uygulamasındaki kısayol adı.
    public static let defaultShortcutName = "Odak Değiştir"
    private let kLastState = "kFocusLastState"

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Odak Kapalı"

    public init() {
        refresh()
    }

    public var shortcutName: String {
        let stored = UserDefaults.standard.string(forKey: "kFocusShortcutName")
        return stored?.nilIfEmpty ?? FocusSwitch.defaultShortcutName
    }

    public func toggle() {
        guard shortcutExists() else {
            SwitchManager.shared.showNotification(
                "Kısayollar'da \"\(shortcutName)\" adlı bir kısayol oluşturun (Odak Ayarla eylemi)."
            )
            return
        }

        let result = CommandRunner.shared.runShell("/usr/bin/shortcuts run \(shellQuote(shortcutName))")
        guard result.exitCode == 0 else {
            let detail = result.output.split(separator: "\n").last.map(String.init) ?? "bilinmeyen hata"
            SwitchManager.shared.showNotification("Odak değiştirilemedi: \(detail)")
            return
        }

        let target = !isOn
        UserDefaults.standard.set(target, forKey: kLastState)
        isOn = target
        subtitle = target ? "Odak Açık (bildirimler sessiz)" : "Odak Kapalı"
        SwitchManager.shared.showNotification(target ? "Odak açıldı." : "Odak kapatıldı.")
    }

    public func refresh() {
        // Gerçek durum okunamadığı için son bilinen değer gösterilir.
        isOn = UserDefaults.standard.bool(forKey: kLastState)
        subtitle = isOn ? "Odak Açık (bildirimler sessiz)" : "Odak Kapalı"
    }

    private func shortcutExists() -> Bool {
        let result = CommandRunner.shared.runShell("/usr/bin/shortcuts list 2>/dev/null")
        return result.output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .contains(shortcutName)
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
