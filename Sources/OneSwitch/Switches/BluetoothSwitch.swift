import Foundation
import SwiftUI
import Combine
import Darwin

/// Bluetooth radyosunu açıp kapatan anahtar.
///
/// Apple herkese açık bir API sunmadığı için sırasıyla şunlar denenir:
/// 1. Kuruluysa `blueutil` komutu (en güvenilir yol).
/// 2. IOBluetooth çerçevesindeki özel tercih fonksiyonları.
public final class BluetoothSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "bluetooth_toggle"
    public let title = "Bluetooth"
    public let iconName = "dot.radiowaves.right"
    public let activeColor = Color.blue
    public let category = SwitchCategory.system
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Bluetooth Kapalı"

    public init() {
        refresh()
    }

    public func toggle() {
        let target = !isOn
        guard setPower(target) else {
            SwitchManager.shared.showNotification(
                target
                ? "Bluetooth açılamadı. Terminalde `brew install blueutil` kurmayı deneyin."
                : "Bluetooth kapatılamadı. Terminalde `brew install blueutil` kurmayı deneyin."
            )
            return
        }

        SystemStateReader.shared.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refresh()
        }
    }

    public func refresh() {
        let cached = SystemStateReader.shared.value(for: "BluetoothPower")
        if cached == "1" || cached == "0" {
            isOn = cached == "1"
        } else if let state = frameworkPower() {
            isOn = state
        } else {
            isOn = false
        }
        subtitle = isOn ? "Bluetooth Açık" : "Bluetooth Kapalı"
    }

    // MARK: - blueutil

    /// Menü uygulamaları kullanıcının PATH'ini almaz; `command -v` Homebrew'u
    /// bulamıyordu. Bilinen kurulum yolları doğrudan denenir.
    private func blueutilPath() -> String? {
        ["/opt/homebrew/bin/blueutil", "/usr/local/bin/blueutil"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - IOBluetooth özel çerçevesi

    private static let frameworkHandle: UnsafeMutableRawPointer? = {
        let paths = [
            "/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth",
            "/System/Library/PrivateFrameworks/IOBluetooth.framework/IOBluetooth"
        ]
        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) {
                return handle
            }
        }
        return nil
    }()

    private typealias GetPowerFn = @convention(c) () -> Int32
    private typealias SetPowerFn = @convention(c) (Int32) -> Int32

    private func frameworkSymbols() -> (get: GetPowerFn, set: SetPowerFn)? {
        guard let handle = BluetoothSwitch.frameworkHandle else { return nil }
        guard let getPtr = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState"),
              let setPtr = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState") else {
            return nil
        }
        return (unsafeBitCast(getPtr, to: GetPowerFn.self),
                unsafeBitCast(setPtr, to: SetPowerFn.self))
    }

    private func frameworkPower() -> Bool? {
        guard let symbols = frameworkSymbols() else { return nil }
        return symbols.get() != 0
    }

    private func setPower(_ on: Bool) -> Bool {
        if let path = blueutilPath() {
            let result = CommandRunner.shared.runShell("\(path) -p \(on ? 1 : 0) 2>/dev/null")
            if result.exitCode == 0 { return true }
        }
        if let symbols = frameworkSymbols() {
            return symbols.set(on ? 1 : 0) == 0
        }
        return false
    }
}
