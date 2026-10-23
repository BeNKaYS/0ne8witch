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
    
    /// Dock'a ayraç ekler.
    ///
    /// macOS Dock'a serbestçe yerleştirilebilir görünür bir çizgi desteği sunmadığı için
    /// ayraç, uygulama simgesi silinince kalan "?" yer tutucusuna benzeyen; fakat ortasında
    /// soru işareti yerine dikey çizgi bulunan küçük bir karo olarak eklenir.
    public func addDockSpacer(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let template = self.ensureDockSeparatorApp() else {
                DispatchQueue.main.async { completion("Dock ayracı oluşturulamadı.") }
                return
            }
            
            let fm = FileManager.default
            let baseDir = template.deletingLastPathComponent()
            let uniqueURL = baseDir.appendingPathComponent("DockSeparator-\(Int(Date().timeIntervalSince1970 * 1000)).app")
            
            do {
                try fm.copyItem(at: template, to: uniqueURL)
            } catch {
                DispatchQueue.main.async { completion("Dock ayracı hazırlanamadı.") }
                return
            }
            
            // Dock simgeyi tanısın diye yardımcı uygulamayı LaunchServices'e kaydet
            _ = CommandRunner.shared.runShell("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f \"\(uniqueURL.path)\"")
            
            guard let dock = UserDefaults(suiteName: "com.apple.dock") else {
                DispatchQueue.main.async { completion("Dock ayarlarına erişilemedi.") }
                return
            }
            
            var apps = (dock.array(forKey: "persistent-apps") as? [[String: Any]]) ?? []
            apps.append(self.dockEntry(for: uniqueURL))
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
            var removed = 0
            let filtered = apps.filter { item in
                let isSpacer = self.isSpacerTile(item)
                if isSpacer { removed += 1 }
                return !isSpacer
            }
            
            guard removed > 0 else {
                DispatchQueue.main.async { completion("Dock'ta ayraç bulunamadı.") }
                return
            }
            
            dock.set(filtered, forKey: "persistent-apps")
            dock.synchronize()
            _ = CommandRunner.shared.runShell("killall Dock")
            
            // Yardımcı ayraç uygulamalarını temizle
            let fm = FileManager.default
            if let items = try? fm.contentsOfDirectory(at: self.separatorBaseDir(), includingPropertiesForKeys: nil) {
                for item in items where item.lastPathComponent.hasPrefix("DockSeparator") {
                    try? fm.removeItem(at: item)
                }
            }
            
            DispatchQueue.main.async {
                completion("\(removed) Dock ayracı kaldırıldı.")
            }
        }
    }
    
    // MARK: - Dock ayracı yardımcıları
    
    private func separatorBaseDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("0ne8witch", isDirectory: true)
    }
    
    /// Dock'ta ayraç karosu olarak görünen küçük yardımcı uygulamayı oluşturur.
    private func ensureDockSeparatorApp() -> URL? {
        let fm = FileManager.default
        let appURL = separatorBaseDir().appendingPathComponent("DockSeparator.app", isDirectory: true)
        let contents = appURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSDir = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let executable = macOSDir.appendingPathComponent("DockSeparator")
        let icnsURL = resources.appendingPathComponent("Separator.icns")
        
        if fm.fileExists(atPath: executable.path), fm.fileExists(atPath: icnsURL.path) {
            return appURL
        }
        
        do {
            try fm.createDirectory(at: macOSDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: resources, withIntermediateDirectories: true)
            
            let info: [String: Any] = [
                "CFBundleExecutable": "DockSeparator",
                "CFBundleIdentifier": "com.avenox.0ne8witch.dockseparator",
                "CFBundleName": "Ayrac",
                "CFBundleDisplayName": "Ayrac",
                "CFBundlePackageType": "APPL",
                "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1",
                "CFBundleIconFile": "Separator",
                "LSUIElement": true,
                "LSMinimumSystemVersion": "13.0"
            ]
            let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try infoData.write(to: contents.appendingPathComponent("Info.plist"))
            
            // Tıklanınca hiçbir şey yapmayan sessiz yardımcı
            try "#!/bin/bash\nexit 0\n".write(to: executable, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
            
            guard try writeSeparatorIcon(to: resources) else { return nil }
            return appURL
        } catch {
            return nil
        }
    }
    
    /// "?" yer tutucusuna benzeyen; ortasında dikey çizgi bulunan karo ikonu üretir.
    private func writeSeparatorIcon(to resources: URL) throws -> Bool {
        let fm = FileManager.default
        let pixelSize = 1024
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return false }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        
        let canvas = NSRect(x: 0, y: 0, width: CGFloat(pixelSize), height: CGFloat(pixelSize))
        let tile = NSBezierPath(roundedRect: canvas, xRadius: 220, yRadius: 220)
        
        // Yer tutucu görünümlü açık gri degrade zemin
        let background = NSGradient(colors: [
            NSColor(calibratedWhite: 0.96, alpha: 1.0),
            NSColor(calibratedWhite: 0.74, alpha: 1.0)
        ])!
        background.draw(in: tile, angle: -90)
        
        // Ortada dikey çizgi
        let barWidth: CGFloat = 46
        let barHeight: CGFloat = 520
        let barRect = NSRect(
            x: (CGFloat(pixelSize) - barWidth) / 2,
            y: (CGFloat(pixelSize) - barHeight) / 2,
            width: barWidth,
            height: barHeight
        )
        NSColor(calibratedWhite: 0.32, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        NSGraphicsContext.restoreGraphicsState()
        
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return false }
        let pngURL = resources.appendingPathComponent("Separator.png")
        try pngData.write(to: pngURL)
        
        let iconsetURL = resources.appendingPathComponent("Separator.iconset", isDirectory: true)
        try? fm.removeItem(at: iconsetURL)
        try fm.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        
        let variants: [(String, Int)] = [
            ("icon_16x16", 16), ("icon_16x16@2x", 32),
            ("icon_32x32", 32), ("icon_32x32@2x", 64),
            ("icon_128x128", 128), ("icon_128x128@2x", 256),
            ("icon_256x256", 256), ("icon_256x256@2x", 512),
            ("icon_512x512", 512), ("icon_512x512@2x", 1024)
        ]
        for (name, size) in variants {
            let outURL = iconsetURL.appendingPathComponent("\(name).png")
            _ = CommandRunner.shared.runShell("sips -z \(size) \(size) \"\(pngURL.path)\" --out \"\(outURL.path)\" >/dev/null 2>&1")
        }
        
        let icnsURL = resources.appendingPathComponent("Separator.icns")
        let result = CommandRunner.shared.runShell("iconutil -c icns \"\(iconsetURL.path)\" -o \"\(icnsURL.path)\"")
        try? fm.removeItem(at: iconsetURL)
        try? fm.removeItem(at: pngURL)
        
        return result.exitCode == 0 && fm.fileExists(atPath: icnsURL.path)
    }
    
    /// Dock'un persistent-apps listesine eklenecek karo girdisi.
    private func dockEntry(for appURL: URL) -> [String: Any] {
        var urlString = appURL.absoluteString
        if !urlString.hasSuffix("/") {
            urlString += "/"
        }
        return [
            "tile-data": [
                "file-data": [
                    "_CFURLString": urlString,
                    "_CFURLStringType": 15
                ],
                "file-label": "Ayrac",
                "file-type": 169
            ],
            "tile-type": "file-tile"
        ]
    }
    
    /// Girdinin bizim eklediğimiz bir ayraç olup olmadığını belirler.
    private func isSpacerTile(_ item: [String: Any]) -> Bool {
        if let type = item["tile-type"] as? String, type.contains("spacer") {
            return true
        }
        if let tile = item["tile-data"] as? [String: Any],
           let fileData = tile["file-data"] as? [String: Any],
           let url = fileData["_CFURLString"] as? String,
           url.contains("DockSeparator") {
            return true
        }
        return false
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
