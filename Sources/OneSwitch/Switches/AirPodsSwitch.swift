import Foundation
import SwiftUI
import Combine
import CoreAudio

/// Ses çıkışını tek tıkla AirPods (veya başka bir Bluetooth kulaklık) ile
/// dahili hoparlör arasında değiştiren anahtar. Herkese açık CoreAudio API'si kullanılır.
public final class AirPodsSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "airpods"
    public let title = "AirPods'e Geç"
    public let iconName = "airpodspro"
    public let activeColor = Color.cyan
    public let category = SwitchCategory.media
    public let hasOptions = false

    /// Adında bu kelimelerden biri geçen çıkış aygıtı kablosuz kulaklık sayılır.
    private let wirelessKeywords = ["airpods", "beats", "bluetooth", "kablosuz", "wireless"]

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Ses çıkışı okunuyor..."

    public init() {
        refresh()
    }

    public func toggle() {
        let devices = outputDevices()
        let current = defaultOutputDeviceID()

        if let current, isWireless(name: deviceName(current)) {
            // Kablosuz çıkıştayız; dahili hoparlöre dön.
            if let builtIn = devices.first(where: { isBuiltIn(name: deviceName($0)) }) ?? devices.first {
                setDefaultOutput(builtIn)
            }
        } else {
            guard let wireless = devices.first(where: { isWireless(name: deviceName($0)) }) else {
                SwitchManager.shared.showNotification("Bağlı AirPods veya Bluetooth kulaklık bulunamadı.")
                return
            }
            setDefaultOutput(wireless)
        }

        SystemStateReader.shared.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        guard let current = defaultOutputDeviceID() else {
            isOn = false
            subtitle = "Ses çıkışı okunamadı"
            return
        }
        let name = deviceName(current)
        isOn = isWireless(name: name)
        let label = name.isEmpty ? "Bilinmiyor" : name
        subtitle = isOn ? "Kablosuz ses: \(label)" : "Ses: \(label)"
    }

    // MARK: - CoreAudio yardımcıları

    private func defaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    private func setDefaultOutput(_ deviceID: AudioDeviceID) {
        var value = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &value
        )
    }

    private func deviceName(_ deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer -> OSStatus in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else { return "" }
        return name as String
    }

    private func outputDevices() -> [AudioDeviceID] {
        var size = UInt32(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices
        ) == noErr else { return [] }

        return devices.filter { hasOutputChannels($0) }
    }

    private func hasOutputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, raw) == noErr else {
            return false
        }
        let bufferList = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self)
        )
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private func isWireless(name: String) -> Bool {
        let lower = name.lowercased()
        return wirelessKeywords.contains { lower.contains($0) }
    }

    private func isBuiltIn(name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("macbook") || lower.contains("built-in") || lower.contains("dahili")
            || lower.contains("hoparlör") || lower.contains("speakers")
    }
}
