import Foundation
import SwiftUI
import Combine
import Darwin

/// Ekranın ortam ışığına göre renk sıcaklığını ayarlayan True Tone anahtarı.
///
/// Apple herkese açık API sunmadığı için CoreBrightness içindeki özel
/// `CBAdaptationClient` sınıfı kullanılıyor.
public final class TrueToneSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "true_tone"
    public let title = "True Tone"
    public let iconName = "sun.max.fill"
    public let activeColor = Color.yellow
    public let category = SwitchCategory.display
    public let hasOptions = false

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Ortam Işığına Uyum Kapalı"

    private static var client: NSObject?

    public init() {
        refresh()
    }

    public func toggle() {
        let target = !isOn
        switch apply(target) {
        case .success:
            isOn = target
            subtitle = target ? "Ortam Işığına Uyum Açık" : "Ortam Işığına Uyum Kapalı"
        case .unsupported:
            SwitchManager.shared.showNotification("True Tone bu ekranda veya Mac'te desteklenmiyor.")
        case .failed:
            SwitchManager.shared.showNotification("True Tone değiştirilemedi. Sistem Ayarları → Ekran'dan deneyin.")
        }
    }

    public func refresh() {
        if let state = currentState() {
            isOn = state
        }
        subtitle = isOn ? "Ortam Işığına Uyum Açık" : "Ortam Işığına Uyum Kapalı"
    }

    private enum ApplyResult { case success, unsupported, failed }

    // MARK: - CoreBrightness köprüsü

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

    private static let getEnabledSelector = NSSelectorFromString("getEnabled")
    private static let setEnabledSelector = NSSelectorFromString("setEnabled:")
    private static let supportedSelector = NSSelectorFromString("supported")

    private typealias GetBoolImplementation = @convention(c) (AnyObject, Selector) -> ObjCBool
    private typealias SetBoolImplementation = @convention(c) (AnyObject, Selector, ObjCBool) -> ObjCBool

    private func adaptationClient() -> NSObject? {
        if let existing = TrueToneSwitch.client { return existing }
        guard TrueToneSwitch.frameworkHandle != nil,
              let cls = NSClassFromString("CBAdaptationClient") as? NSObject.Type else {
            return nil
        }
        let instance = cls.init()
        TrueToneSwitch.client = instance
        return instance
    }

    private func currentState() -> Bool? {
        guard let client = adaptationClient(),
              let method = class_getInstanceMethod(type(of: client), TrueToneSwitch.getEnabledSelector),
              method_getNumberOfArguments(method) == 2 else {
            return nil
        }
        let implementation = unsafeBitCast(
            method_getImplementation(method),
            to: GetBoolImplementation.self
        )
        return implementation(client, TrueToneSwitch.getEnabledSelector).boolValue
    }

    private func apply(_ on: Bool) -> ApplyResult {
        guard let client = adaptationClient() else { return .unsupported }

        if let supportedMethod = class_getInstanceMethod(type(of: client), TrueToneSwitch.supportedSelector),
           method_getNumberOfArguments(supportedMethod) == 2 {
            let supported = unsafeBitCast(
                method_getImplementation(supportedMethod),
                to: GetBoolImplementation.self
            )
            guard supported(client, TrueToneSwitch.supportedSelector).boolValue else {
                return .unsupported
            }
        }

        guard let method = class_getInstanceMethod(type(of: client), TrueToneSwitch.setEnabledSelector),
              method_getNumberOfArguments(method) == 3 else {
            return .unsupported
        }

        // `setEnabled:` bazı sürümlerde değer döndürür, bazılarında döndürmez;
        // bu yüzden sonuç ayrıca okunarak doğrulanır.
        let implementation = unsafeBitCast(
            method_getImplementation(method),
            to: SetBoolImplementation.self
        )
        _ = implementation(client, TrueToneSwitch.setEnabledSelector, ObjCBool(on))

        return currentState() == on ? .success : .failed
    }
}
