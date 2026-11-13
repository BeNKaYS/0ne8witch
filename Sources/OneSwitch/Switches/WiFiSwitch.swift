import Foundation
import SwiftUI
import Combine

/// Wi-Fi radyosunu açıp kapatan anahtar.
///
/// `networksetup` yönetici yetkisi istediği için her değişiklikte macOS parola
/// penceresi açılır. Kullanıcı vazgeçerse durum olduğu gibi kalır.
public final class WiFiSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "wifi_toggle"
    public let title = "Wi-Fi"
    public let iconName = "wifi"
    public let activeColor = Color.blue
    public let category = SwitchCategory.system
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Wi-Fi Durumu Okunuyor..."

    public init() {
        refresh()
    }

    public func toggle() {
        guard let device = SystemStateReader.shared.value(for: "WiFiDevice").nilIfEmpty else {
            SwitchManager.shared.showNotification("Wi-Fi aygıtı bulunamadı.")
            return
        }
        let target = isOn ? "off" : "on"
        let command = "/usr/sbin/networksetup -setairportpower \(device) \(target)"
        let script = "do shell script \"\(command)\" with administrator privileges"
        let result = CommandRunner.shared.runAppleScript(script)

        if result.success {
            SwitchManager.shared.showNotification(target == "on" ? "Wi-Fi açıldı." : "Wi-Fi kapatıldı.")
        } else {
            // Kullanıcı parola penceresini iptal etti veya komut reddedildi.
            SwitchManager.shared.showNotification("Wi-Fi değiştirilmedi.")
        }

        SystemStateReader.shared.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let val = SystemStateReader.shared.value(for: "WiFiPower")
        let on = val.lowercased().contains("on")
        self.isOn = on
        self.subtitle = on ? "Wi-Fi Açık" : "Wi-Fi Kapalı"
    }
}

extension String {
    /// Boş veya yalnızca boşluktan oluşan değerler için nil döndürür.
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
