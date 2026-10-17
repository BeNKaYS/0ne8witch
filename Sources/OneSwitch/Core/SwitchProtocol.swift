import SwiftUI
import Combine

/// Anahtar kategorileri
public enum SwitchCategory: String, CaseIterable, Identifiable {
    case all = "Tümü"
    case system = "Sistem"
    case display = "Ekran & Masaüstü"
    case media = "Ses & Medya"
    case utility = "Araçlar"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .system: return "gearshape"
        case .display: return "display"
        case .media: return "speaker.wave.2"
        case .utility: return "wrench.and.screwdriver"
        }
    }
}

/// Tüm OneSwitch anahtarlarının uyması gereken temel protokol
public protocol SwitchItemProtocol: AnyObject, Identifiable {
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var iconName: String { get }
    var activeColor: Color { get }
    var category: SwitchCategory { get }
    var isOn: Bool { get set }
    var hasOptions: Bool { get }
    
    func toggle()
    func refresh()
}
