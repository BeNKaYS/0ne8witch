import AppKit
import Foundation
import UniformTypeIdentifiers

/// 0ne8witch Hızlı Eylemleri (Tek tıkla çalışan yardımcı araçlar)
public final class QuickActions {
    public static let shared = QuickActions()
    
    private init() {}
    
    /// Çöp kutusunu uyarı pencerelerini otomatik atlayarak sessizce ve güvenle boşaltır
    public func emptyTrash(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            tell application "Finder"
                try
                    set c to count items of trash
                    if c = 0 then
                        return "ALREADY_EMPTY"
                    end if
                    set oldWarn to warns before emptying of trash
                    set warns before emptying of trash to false
                    empty trash
                    set warns before emptying of trash to oldWarn
                    return (c as string)
                on error errMsg
                    return "ERROR:" & errMsg
                end try
            end tell
            """
            let res = CommandRunner.shared.runAppleScript(script)
            DispatchQueue.main.async {
                if res.output == "ALREADY_EMPTY" {
                    completion("Çöp kutusu zaten boş.")
                } else if res.output.starts(with: "ERROR:") {
                    // Fallback: Doğrudan shell temizliği dene
                    CommandRunner.shared.runShell("rm -rf ~/.Trash/* 2>/dev/null")
                    completion("Çöp kutusu temizlendi!")
                } else if let count = Int(res.output) {
                    completion("Çöp boşaltıldı! (\(count) öğe temizlendi)")
                } else {
                    completion("Çöp kutusu başarıyla boşaltıldı!")
                }
            }
        }
    }
    
    /// Panoyu (Clipboard) tamamen temizler
    public func clearPasteboard() {
        NSPasteboard.general.clearContents()
    }
    
    /// Ekrandaki herhangi bir pikselin rengini büyüteçle seçip HEX kodunu panoya kopyalar
    public func pickColor(completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            NSColorSampler().show { selectedColor in
                guard let color = selectedColor?.usingColorSpace(.sRGB) else {
                    completion("Renk seçimi iptal edildi.")
                    return
                }
                let r = Int(color.redComponent * 255.0)
                let g = Int(color.greenComponent * 255.0)
                let b = Int(color.blueComponent * 255.0)
                let hex = String(format: "#%02X%02X%02X", r, g, b)
                
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(hex, forType: .string)
                completion("Renk kopyalandı: \(hex)")
            }
        }
    }
    
    /// Geliştiriciler için takılı kalan localhost portlarını (3000, 5000, 8000, 8080, 8888) temizler
    public func killDevPorts(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let targetPorts = [3000, 5000, 8000, 8080, 8888]
            var killedPorts: [Int] = []
            
            for port in targetPorts {
                let res = CommandRunner.shared.runShell("lsof -ti :\(port)")
                let pids = res.output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if !pids.isEmpty {
                    for pid in pids {
                        _ = CommandRunner.shared.runShell("kill -9 \(pid) 2>/dev/null")
                    }
                    killedPorts.append(port)
                }
            }
            
            DispatchQueue.main.async {
                if killedPorts.isEmpty {
                    completion("Geliştirici portları (3000, 5000, 8000, 8080) zaten boş.")
                } else {
                    let list = killedPorts.map { String($0) }.joined(separator: ", ")
                    completion("Portlar sonlandırıldı: :\(list)")
                }
            }
        }
    }
    
    /// Takılı olan tüm harici / çıkarılabilir diskleri ve USB bellekleri güvenle çıkarır
    public func ejectAllDisks(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            tell application "Finder"
                set diskList to every disk whose ejectable is true and local volume is true
                set diskCount to count of diskList
                if diskCount = 0 then
                    return "NO_DISKS"
                end if
                repeat with d in diskList
                    try
                        eject d
                    end try
                end repeat
                return (diskCount as string)
            end tell
            """
            let res = CommandRunner.shared.runAppleScript(script)
            DispatchQueue.main.async {
                if res.output == "NO_DISKS" {
                    completion("Çıkarılacak harici disk bulunamadı.")
                } else if let count = Int(res.output) {
                    completion("\(count) harici disk güvenle çıkarıldı.")
                } else {
                    completion("Harici diskler çıkarıldı.")
                }
            }
        }
    }
    
    /// RAM bellek önbelleğini temizleyip sistemi rahatlatır
    public func purgeMemory(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CommandRunner.shared.runShell("purge 2>/dev/null")
            SystemMonitor.shared.updateStats()
            DispatchQueue.main.async {
                completion("Bellek önbelleği temizlendi!")
            }
        }
    }
    
    /// Ekranı anında kilitler (Ctrl + Cmd + Q)
    public func lockScreen() {
        let script = "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"
        CommandRunner.shared.runAppleScript(script)
    }
    
    /// Ekran koruyucuyu hemen başlatır
    public func startScreenSaver() {
        CommandRunner.shared.runShell("open -a ScreenSaverEngine")
    }
    
    /// Ekranı hemen uyku moduna geçirir
    public func sleepDisplay() {
        CommandRunner.shared.runShell("pmset displaysleepnow")
    }
    
    /// Dock'a küçük bir boşluk (grup ayracı) ekler.
    public func addDockSpacer(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let dock = UserDefaults(suiteName: "com.apple.dock") else {
                DispatchQueue.main.async { completion("Dock ayarlarına erişilemedi.") }
                return
            }
            
            var apps = (dock.array(forKey: "persistent-apps") as? [[String: Any]]) ?? []
            apps.append(["tile-type": "small-spacer-tile"])
            dock.set(apps, forKey: "persistent-apps")
            dock.synchronize()
            
            _ = CommandRunner.shared.runShell("killall Dock")
            DispatchQueue.main.async {
                completion("Dock'a boşluk ayracı eklendi.")
            }
        }
    }
    
    /// Dock'taki tüm boşluk ayraçlarını kaldırır.
    public func removeDockSpacers(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let dock = UserDefaults(suiteName: "com.apple.dock") else {
                DispatchQueue.main.async { completion("Dock ayarlarına erişilemedi.") }
                return
            }
            
            let apps = (dock.array(forKey: "persistent-apps") as? [[String: Any]]) ?? []
            var removed = 0
            let filtered = apps.filter { item in
                if let type = item["tile-type"] as? String, type.contains("spacer") {
                    removed += 1
                    return false
                }
                return true
            }
            
            guard removed > 0 else {
                DispatchQueue.main.async { completion("Dock'ta ayraç bulunamadı.") }
                return
            }
            
            dock.set(filtered, forKey: "persistent-apps")
            dock.synchronize()
            _ = CommandRunner.shared.runShell("killall Dock")
            
            DispatchQueue.main.async {
                completion("\(removed) ayraç kaldırıldı.")
            }
        }
    }
    
    /// Xcode DerivedData önbelleğini temizler
    public func cleanXcodeDerivedData(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let path = NSString(string: "~/Library/Developer/Xcode/DerivedData").expandingTildeInPath
            let res = CommandRunner.shared.runShell("rm -rf \"\(path)\"/* 2>/dev/null")
            DispatchQueue.main.async {
                if res.exitCode == 0 {
                    completion("Xcode önbelleği temizlendi!")
                } else {
                    completion("Temizleme sırasında bir sorun oluştu.")
                }
            }
        }
    }

    /// Kullanıcıya uygulama seçtirir ve karantina niteliğini kaldırır.
    ///
    /// macOS, indirilen bir uygulamayı "hasarlı" ya da "geliştirici doğrulanamadı"
    /// diyerek açmayı reddettiğinde sorun genelde `com.apple.quarantine`
    /// niteliğidir. Bu eylem niteliği kaldırır.
    public func repairDamagedApp(completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Onarılacak uygulamayı seçin"
            panel.message = "Açılmayan uygulamayı (.app) seçin; karantina niteliği kaldırılacak."
            panel.prompt = "Onar"
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.treatsFilePackagesAsDirectories = false
            if let appType = UTType(filenameExtension: "app") {
                panel.allowedContentTypes = [appType]
            }

            guard panel.runModal() == .OK, let url = panel.url else {
                completion("Onarma iptal edildi.")
                return
            }

            // Seçilen yol gerçekten bir uygulama paketi mi?
            guard url.pathExtension.lowercased() == "app" else {
                completion("Seçilen dosya bir .app paketi değil.")
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let quoted = url.path.replacingOccurrences(of: "'", with: "'\\''")
                let result = CommandRunner.shared.runShell("xattr -r -d com.apple.quarantine '\(quoted)' 2>&1")
                let name = url.deletingPathExtension().lastPathComponent

                DispatchQueue.main.async {
                    if result.exitCode == 0 {
                        completion("\(name) onarıldı. Artık açılabilir.")
                    } else if result.output.contains("No such xattr") {
                        completion("\(name) zaten sağlıklı görünüyor (karantina yok).")
                    } else {
                        completion("\(name) onarılamadı: \(result.output)")
                    }
                }
            }
        }
    }

    /// Yerel ve dış IP adresini okuyup panoya kopyalar.
    public func copyIPAddresses(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Aktif arayüzü bul: varsayılan rota hangi cihazdan çıkıyor?
            let route = CommandRunner.shared.runShell("route -n get default 2>/dev/null | awk '/interface:/{print $2}'")
            let device = route.output.split(separator: "\n").first.map(String.init) ?? "en0"

            let localResult = CommandRunner.shared.runShell(
                "ipconfig getifaddr \(device) 2>/dev/null || ifconfig \(device) 2>/dev/null | awk '/inet /{print $2; exit}'"
            )
            let localIP = localResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Dış IP için kısa zaman aşımıyla tek istek.
            var externalIP = ""
            if let url = URL(string: "https://api.ipify.org") {
                var request = URLRequest(url: url)
                request.timeoutInterval = 5
                let semaphore = DispatchSemaphore(value: 0)
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    if let data, let text = String(data: data, encoding: .utf8) {
                        externalIP = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    semaphore.signal()
                }.resume()
                _ = semaphore.wait(timeout: .now() + 6)
            }

            DispatchQueue.main.async {
                var lines: [String] = []
                if !localIP.isEmpty { lines.append("Yerel (\(device)): \(localIP)") }
                if !externalIP.isEmpty { lines.append("Dış IP: \(externalIP)") }

                guard !lines.isEmpty else {
                    completion("IP adresi okunamadı. Ağ bağlantısını kontrol edin.")
                    return
                }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
                completion(lines.joined(separator: " · ") + " (panoya kopyalandı)")
            }
        }
    }
}
