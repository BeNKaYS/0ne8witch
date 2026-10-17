import Foundation
import SwiftUI
import Combine

/// Sistem mikrofonunu anında susturan veya sesini açan anahtar
public final class MicrophoneMuteSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "mute_microphone"
    public let title = "Mikrofonu Sustur"
    public let iconName = "mic.slash.fill"
    public let activeColor = Color.red
    public let category = SwitchCategory.media
    public let hasOptions = false
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Mikrofon Açık"
    
    private var previousVolume: Int = 75
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        if isOn {
            // Sesi aç
            let volToRestore = previousVolume > 0 ? previousVolume : 75
            let script = "set volume input volume \(volToRestore)"
            CommandRunner.shared.runAppleScript(script)
            self.isOn = false
            self.subtitle = "Mikrofon Açık (%\(volToRestore))"
        } else {
            // Mevcut sesi al ve 0 yap
            let currentVol = getCurrentVolume()
            if currentVol > 0 {
                previousVolume = currentVol
            }
            let script = "set volume input volume 0"
            CommandRunner.shared.runAppleScript(script)
            self.isOn = true
            self.subtitle = "Mikrofon Sessizde"
        }
    }
    
    public func refresh() {
        let vol = getCurrentVolume()
        let isMuted = (vol == 0)
        self.isOn = isMuted
        self.subtitle = isMuted ? "Mikrofon Sessizde" : "Mikrofon Açık (%\(vol))"
    }
    
    private func getCurrentVolume() -> Int {
        let res = CommandRunner.shared.runAppleScript("input volume of (get volume settings)")
        if res.success, let vol = Int(res.output.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return vol
        }
        return 50
    }
}
