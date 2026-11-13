import Foundation

/// Menü açılırken gereken sistem durumlarını tek bir shell çağrısında toplayan
/// ve çok kısa süre önbelleğe alan yardımcı sınıf.
///
/// Daha önce her anahtar kendi `defaults`/`pgrep`/`pmset` sürecini başlatıyordu;
/// bu da menünün açılmasını saniyelerce geciktiriyordu.
public final class SystemStateReader {
    public static let shared = SystemStateReader()
    
    private let lock = NSLock()
    /// Okumaları sıraya dizer: arka plan ön ısıtması sürerken gelen ikinci istek
    /// yeni bir zsh süreci başlatmaz, ilkinin bitmesini bekleyip sonucunu kullanır.
    private let readLock = NSLock()
    private var cachedValues: [String: String]?
    private var cachedAt: Date = .distantPast
    /// Aynı açılış/refresh turundaki okumalar tek çağrıyı paylaşsın diye kısa tutuldu.
    private let cacheLifetime: TimeInterval = 1.0
    
    private init() {}
    
    /// Verilen anahtarın son okunan değerini döndürür (yoksa boş string).
    public func value(for key: String) -> String {
        return snapshot()[key] ?? ""
    }
    
    /// Önbelleği arka planda tazeler, bitince `completion`'ı ana iş parçacığında çağırır.
    /// Menü açılırken ilk kare shell çağrılarını beklemez.
    public func prewarmAsync(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.snapshot()
            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
    
    /// `Volume` satırı: "çıkış_sessiz,giriş_seviyesi" (ör. "false,75").
    public var outputMuted: Bool? {
        let parts = value(for: "Volume").split(separator: ",")
        guard parts.count == 2 else { return nil }
        return parts[0].lowercased() == "true"
    }

    public var inputVolume: Int? {
        let parts = value(for: "Volume").split(separator: ",")
        guard parts.count == 2 else { return nil }
        return Int(parts[1])
    }

    /// Bir anahtar değiştirildikten sonra önbelleği geçersiz kılar.
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        cachedValues = nil
        cachedAt = .distantPast
    }
    
    private func cachedIfFresh() -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        guard let values = cachedValues, Date().timeIntervalSince(cachedAt) < cacheLifetime else {
            return nil
        }
        return values
    }

    private func snapshot() -> [String: String] {
        if let values = cachedIfFresh() { return values }

        readLock.lock()
        defer { readLock.unlock() }
        // Biz beklerken başka bir okuma bitirmiş olabilir.
        if let values = cachedIfFresh() { return values }

        let values = readSnapshot()
        
        lock.lock()
        cachedValues = values
        cachedAt = Date()
        lock.unlock()
        return values
    }
    
    private func readSnapshot() -> [String: String] {
        // Tüm okumalar tek zsh sürecinde yapılır.
        let script = """
        printf 'AppleInterfaceStyle=%s\\n' "$(defaults read -g AppleInterfaceStyle 2>/dev/null)"
        printf 'FinderCreateDesktop=%s\\n' "$(defaults read com.apple.finder CreateDesktop 2>/dev/null)"
        printf 'DockAutohide=%s\\n' "$(defaults read com.apple.dock autohide 2>/dev/null)"
        printf 'AppleShowAllExtensions=%s\\n' "$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null)"
        printf 'FinderShowAllFiles=%s\\n' "$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null)"
        printf 'WindowManagerStandardHideWidgets=%s\\n' "$(defaults read com.apple.WindowManager StandardHideWidgets 2>/dev/null)"
        printf 'WindowManagerGloballyEnabled=%s\\n' "$(defaults read com.apple.WindowManager GloballyEnabled 2>/dev/null)"
        printf 'ScrollDirection=%s\\n' "$(defaults read NSGlobalDomain com.apple.swipescrolldirection 2>/dev/null)"
        printf 'LowPowerMode=%s\\n' "$(pmset -g 2>/dev/null | awk '/lowpowermode/ {print $2; exit}')"
        printf 'Caffeinate=%s\\n' "$(pgrep caffeinate 2>/dev/null | tr '\\n' ' ')"
        printf 'UserLibrary=%s\\n' "$(ls -ldO "$HOME/Library" 2>/dev/null)"
        printf 'FinderPathbar=%s\\n' "$(defaults read com.apple.finder ShowPathbar 2>/dev/null)"
        printf 'FinderStatusBar=%s\\n' "$(defaults read com.apple.finder ShowStatusBar 2>/dev/null)"
        printf 'MenuBarAutoHide=%s\\n' "$(defaults read NSGlobalDomain _HIHideMenuBar 2>/dev/null)"
        printf 'DockMagnification=%s\\n' "$(defaults read com.apple.dock magnification 2>/dev/null)"
        printf 'DockRecents=%s\\n' "$(defaults read com.apple.dock show-recents 2>/dev/null)"
        printf 'ClockSeconds=%s\\n' "$(defaults read com.apple.menuextra.clock ShowSeconds 2>/dev/null)"
        printf 'AskPassword=%s\\n' "$(defaults -currentHost read com.apple.screensaver askForPassword 2>/dev/null || defaults read com.apple.screensaver askForPassword 2>/dev/null)"
        WIFI_DEV=$(networksetup -listallhardwareports 2>/dev/null | awk '/Hardware Port: (Wi-Fi|AirPort)/{getline; print $2; exit}')
        printf 'WiFiDevice=%s\\n' "$WIFI_DEV"
        printf 'WiFiPower=%s\\n' "$(networksetup -getairportpower "$WIFI_DEV" 2>/dev/null | awk -F': ' '{print $2}')"
        printf 'Volume=%s\\n' "$(osascript -e 'set v to get volume settings' -e '(output muted of v as text) & "," & (input volume of v as text)' 2>/dev/null)"
        for B in /opt/homebrew/bin/blueutil /usr/local/bin/blueutil; do
          if [ -x "$B" ]; then printf 'BluetoothPower=%s\\n' "$("$B" -p 2>/dev/null)"; break; fi
        done
        printf 'ScreenshotShadow=%s\\n' "$(defaults read com.apple.screencapture disable-shadow 2>/dev/null)"
        printf 'DockShowHidden=%s\\n' "$(defaults read com.apple.dock showhidden 2>/dev/null)"
        printf 'DockStaticOnly=%s\\n' "$(defaults read com.apple.dock static-only 2>/dev/null)"
        printf 'FinderFoldersFirst=%s\\n' "$(defaults read com.apple.finder _FXSortFoldersFirst 2>/dev/null)"
        printf 'QuitFinder=%s\\n' "$(defaults read com.apple.finder QuitMenuItem 2>/dev/null)"
        """
        
        let result = CommandRunner.shared.runShell(script)
        var values: [String: String] = [:]
        
        for line in result.output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0])
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        
        return values
    }
}
