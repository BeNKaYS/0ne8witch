import Foundation
import SwiftUI
import Combine
import AppKit
import Darwin

/// Dahili ekranın parlaklığını değiştiren anahtar.
///
/// Apple herkese açık bir parlaklık API'si sunmadığı için DisplayServices
/// çerçevesindeki özel fonksiyonlar kullanılıyor. Değer 0.0–1.0 arasıdır.
public final class BrightnessSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "brightness"
    public let title = "Ekran Parlaklığı"
    public let iconName = "sun.max.circle.fill"
    public let activeColor = Color.yellow
    public let category = SwitchCategory.display
    /// Satır görünümünde kaydırıcı gösterilir.
    public let hasOptions = true

    /// Kullanıcı parlaklığı sıfıra çektiğinde geri dönmek için saklanır.
    private var restoreValue: Double = 0.7

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Parlaklık okunuyor..."
    @Published public var level: Double = 0.7

    public init() {
        refresh()
    }

    public func toggle() {
        if level > 0.01 {
            restoreValue = level
            setLevel(0)
        } else {
            setLevel(restoreValue > 0.05 ? restoreValue : 0.7)
        }
    }

    /// Kaydırıcıdan gelen değeri uygular (0.0–1.0).
    public func setLevel(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        guard BrightnessBridge.set(clamped) else {
            SwitchManager.shared.showNotification("Parlaklık bu ekranda değiştirilemiyor.")
            return
        }
        level = clamped
        isOn = clamped > 0.01
        subtitle = "Parlaklık: %\(Int((clamped * 100).rounded()))"
    }

    public func refresh() {
        if let value = BrightnessBridge.get() {
            level = value
            isOn = value > 0.01
            subtitle = "Parlaklık: %\(Int((value * 100).rounded()))"
        } else {
            isOn = false
            subtitle = "Parlaklık okunamadı"
        }
    }
}

/// DisplayServices çerçevesine ince bir köprü.
enum BrightnessBridge {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let functions: (get: GetFn, set: SetFn)? = {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW),
              let getPtr = dlsym(handle, "DisplayServicesGetBrightness"),
              let setPtr = dlsym(handle, "DisplayServicesSetBrightness") else {
            return nil
        }
        return (unsafeBitCast(getPtr, to: GetFn.self), unsafeBitCast(setPtr, to: SetFn.self))
    }()

    static var isAvailable: Bool { functions != nil }

    static func mainDisplayID() -> CGDirectDisplayID? {
        // Menü çubuğunun bulunduğu ekranı hedefle.
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let id = screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        return id
    }

    static func get() -> Double? {
        guard let functions, let id = mainDisplayID() else { return nil }
        var value: Float = -1
        guard functions.get(id, &value) == 0, value >= 0 else { return nil }
        return Double(value)
    }

    @discardableResult
    static func set(_ value: Double) -> Bool {
        guard let functions, let id = mainDisplayID() else { return false }
        return functions.set(id, Float(value)) == 0
    }
}
