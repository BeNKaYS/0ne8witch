import Foundation
import SwiftUI
import Combine

/// Sistem çıkış sesini (hoparlör/kulaklık) tek tıkla susturur.
///
/// Mikrofon anahtarından farkı: bu anahtar *çıkış* sesini kapatır.
/// Durum, `get volume settings` üzerinden okunur; böylece başka bir yerden
/// (menü çubuğu, klavye tuşu) yapılan değişiklikler de yansır.
public final class SystemMuteSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "system_mute"
    public let title = "Sesi Sustur"
    public let iconName = "speaker.slash.fill"
    public let activeColor = Color.orange
    public let category = SwitchCategory.media
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Ses Açık"

    public init() {
        refresh()
    }

    public func toggle() {
        let target = !isOn
        let script = "set volume output muted \(target ? "true" : "false")"
        CommandRunner.shared.runAppleScript(script)
        self.isOn = target
        self.subtitle = target ? "Ses Kapalı" : "Ses Açık"
        SwitchManager.shared.showNotification(target ? "Ses kapatıldı." : "Ses açıldı.")
    }

    public func refresh() {
        // Okunamazsa mevcut durumu koru.
        guard let muted = SystemStateReader.shared.outputMuted else { return }
        self.isOn = muted
        self.subtitle = muted ? "Ses Kapalı" : "Ses Açık"
    }
}
