import AppKit
import Foundation

extension QuickActions {

    // MARK: - Güç Eylemleri

    /// Uyku / oturum kapatma / yeniden başlatma / kapatma arasından seçim sunar.
    ///
    /// Yıkıcı eylemler (oturum, yeniden başlatma, kapatma) aynı pencerede
    /// onay ister; "Vazgeç" varsayılan düğmedir.
    public func showPowerMenu(completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Güç Eylemleri"
        alert.informativeText = "Bu Mac için bir eylem seçin."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Uyku")
        alert.addButton(withTitle: "Oturumu Kapat")
        alert.addButton(withTitle: "Yeniden Başlat")
        alert.addButton(withTitle: "Kapat")
        alert.addButton(withTitle: "Vazgeç")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            runSystemEvent("sleep")
            completion("Mac uykuya alınıyor.")
        case .alertSecondButtonReturn:
            runSystemEvent("log out")
            completion("Oturum kapatılıyor.")
        case .alertThirdButtonReturn:
            runSystemEvent("restart")
            completion("Mac yeniden başlatılıyor.")
        case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1):
            runSystemEvent("shut down")
            completion("Mac kapatılıyor.")
        default:
            break
        }
    }

    private func runSystemEvent(_ event: String) {
        let script = "tell application \"System Events\" to \(event)"
        CommandRunner.shared.runAppleScript(script)
    }

    // MARK: - Servisleri Yenile

    /// Finder, Dock ve menü çubuğu servislerini yeniden başlatır.
    ///
    /// Bu işlem veri kaybına yol açmaz; açık pencereler yerinde kalır.
    public func softRestart(completion: @escaping (String) -> Void) {
        let services = ["Finder", "Dock", "SystemUIServer"]
        let result = CommandRunner.shared.runShell(
            "killall \(services.joined(separator: " ")) 2>&1"
        )

        // killall, süreç yoksa 1 döndürür; bu bir hata değil.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if result.exitCode == 0 || result.output.isEmpty {
                completion("Finder, Dock ve menü çubuğu yenilendi.")
            } else {
                completion("Servisler yenilenemedi: \(result.output)")
            }
        }
    }
}
