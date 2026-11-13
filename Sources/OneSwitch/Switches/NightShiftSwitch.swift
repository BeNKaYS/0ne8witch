import Foundation
import SwiftUI
import Combine
import Darwin

/// Ekranı gece saatlerinde daha sıcak renklere çeviren anahtar.
///
/// Apple'ın herkese açık API'si yok; CoreBrightness içindeki özel
/// `CBBlueLightClient` sınıfı kullanılıyor. Sınıf veya beklenen yapı
/// bulunamazsa anahtar durumu değiştirmez ve nedenini bildirir.
public final class NightShiftSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "nightshift"
    public let title = "Gece Vakti"
    public let iconName = "sun.horizon.fill"
    public let activeColor = Color.orange
    public let category = SwitchCategory.display
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Ekran Normal Renkte"

    private static var client: NSObject?

    public init() {
        refresh()
    }

    public func toggle() {
        let target = !isOn
        switch apply(target) {
        case .success:
            isOn = target
            subtitle = target ? "Ekran Daha Sıcak" : "Ekran Normal Renkte"
        case .unsupported:
            SwitchManager.shared.showNotification("Gece Vakti bu Mac'te veya macOS sürümünde desteklenmiyor.")
        case .failed:
            SwitchManager.shared.showNotification("Gece Vakti değiştirilemedi. Sistem Ayarları → Ekran'dan deneyin.")
        }
        SystemStateReader.shared.invalidate()
    }

    public func refresh() {
        if let state = currentState() {
            isOn = state
        }
        subtitle = isOn ? "Ekran Daha Sıcak" : "Ekran Normal Renkte"
    }

    private enum ApplyResult { case success, unsupported, failed }

    // MARK: - CoreBrightness köprüsü

    /// CBBlueLightClient'ın `getBlueLightStatus:` imzası.
    /// Örnek kodlama: `^{?=BBBi{?={?=ii}{?=ii}}QB}`
    /// Yapı üç bool ile başlar: etkin, açık, zamanlamaya izinli.
    private struct StatusLayout {
        let byteCount: Int
        let alignment: Int
        /// "açık" bayrağının yapı içindeki bayt ofseti.
        let enabledOffset: Int
    }

    private static let frameworkHandle: UnsafeMutableRawPointer? = {
        let paths = [
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
            "/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/A/CoreBrightness"
        ]
        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) { return handle }
        }
        return nil
    }()

    private static let getStatusSelector = NSSelectorFromString("getBlueLightStatus:")
    private static let setEnabledSelector = NSSelectorFromString("setEnabled:")
    private static let supportedSelector = NSSelectorFromString("supported")

    private typealias StatusImplementation = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> ObjCBool
    private typealias SetEnabledImplementation = @convention(c) (AnyObject, Selector, ObjCBool) -> ObjCBool
    private typealias SupportedImplementation = @convention(c) (AnyObject, Selector) -> ObjCBool

    private func blueLightClient() -> NSObject? {
        if let existing = NightShiftSwitch.client { return existing }
        guard NightShiftSwitch.frameworkHandle != nil,
              let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type else {
            return nil
        }
        let instance = cls.init()
        NightShiftSwitch.client = instance
        return instance
    }

    private func statusLayout() -> StatusLayout? {
        guard let client = blueLightClient(),
              let method = class_getInstanceMethod(type(of: client), NightShiftSwitch.getStatusSelector),
              method_getNumberOfArguments(method) == 3,
              let rawType = method_copyArgumentType(method, 2) else {
            return nil
        }
        defer { free(rawType) }

        // Beklediğimiz imza: işaretçi -> yapı, ilk iki alan bool.
        let encoded = String(cString: rawType)
        guard encoded.hasPrefix("^{?=BB") else { return nil }

        // `^` atlanır; yapının gerçek boyutu ve hizası okunur.
        var byteCount = 0
        var alignment = 0
        _ = encoded.withCString { NSGetSizeAndAlignment($0 + 1, &byteCount, &alignment) }
        guard byteCount > 1, byteCount <= 4096, alignment > 0, alignment <= 64 else { return nil }

        return StatusLayout(byteCount: byteCount, alignment: alignment, enabledOffset: 1)
    }

    private func currentState() -> Bool? {
        guard let client = blueLightClient(),
              let layout = statusLayout(),
              let method = class_getInstanceMethod(type(of: client), NightShiftSwitch.getStatusSelector) else {
            return nil
        }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: layout.byteCount,
            alignment: layout.alignment
        )
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: layout.byteCount)

        let implementation = unsafeBitCast(
            method_getImplementation(method),
            to: StatusImplementation.self
        )
        guard implementation(client, NightShiftSwitch.getStatusSelector, buffer).boolValue else {
            return nil
        }

        let value = buffer.load(fromByteOffset: layout.enabledOffset, as: UInt8.self)
        guard value == 0 || value == 1 else { return nil }
        return value == 1
    }

    private func apply(_ on: Bool) -> ApplyResult {
        guard let client = blueLightClient() else { return .unsupported }

        if let supportedMethod = class_getInstanceMethod(type(of: client), NightShiftSwitch.supportedSelector),
           method_getNumberOfArguments(supportedMethod) == 2 {
            let supported = unsafeBitCast(
                method_getImplementation(supportedMethod),
                to: SupportedImplementation.self
            )
            guard supported(client, NightShiftSwitch.supportedSelector).boolValue else {
                return .unsupported
            }
        }

        guard statusLayout() != nil,
              let method = class_getInstanceMethod(type(of: client), NightShiftSwitch.setEnabledSelector),
              method_getNumberOfArguments(method) == 3 else {
            return .unsupported
        }

        let implementation = unsafeBitCast(
            method_getImplementation(method),
            to: SetEnabledImplementation.self
        )
        let accepted = implementation(client, NightShiftSwitch.setEnabledSelector, ObjCBool(on)).boolValue
        guard accepted else { return .failed }

        // Değişikliğin gerçekten uygulandığını doğrula.
        return currentState() == on ? .success : .failed
    }
}
