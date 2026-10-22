import AppKit
import Foundation

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
    
    /// Dock'a ince bir ayraç (boşluk) ekler.
    /// Ayraç, Dock'taki uygulama gruplarını birbirinden ayırmak için kullanılır.
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
                completion("Dock'a ayraç eklendi.")
            }
        }
    }
    
    /// Dock'a eklenmiş tüm ayraçları kaldırır.
    public func removeDockSpacers(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let dock = UserDefaults(suiteName: "com.apple.dock") else {
                DispatchQueue.main.async { completion("Dock ayarlarına erişilemedi.") }
                return
            }
            
            let apps = (dock.array(forKey: "persistent-apps") as? [[String: Any]]) ?? []
            let filtered = apps.filter { item in
                let type = (item["tile-type"] as? String) ?? ""
                return !type.contains("spacer")
            }
            let removed = apps.count - filtered.count
            
            guard removed > 0 else {
                DispatchQueue.main.async { completion("Dock'ta ayraç bulunamadı.") }
                return
            }
            
            dock.set(filtered, forKey: "persistent-apps")
            dock.synchronize()
            
            _ = CommandRunner.shared.runShell("killall Dock")
            DispatchQueue.main.async {
                completion("\(removed) Dock ayracı kaldırıldı.")
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
}
