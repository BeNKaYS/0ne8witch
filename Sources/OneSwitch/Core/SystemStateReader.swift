import Foundation

/// Menü açılırken gereken sistem durumlarını tek bir shell çağrısında toplayan
/// ve çok kısa süre önbelleğe alan yardımcı sınıf.
///
/// Daha önce her anahtar kendi `defaults`/`pgrep`/`pmset` sürecini başlatıyordu;
/// bu da menünün açılmasını saniyelerce geciktiriyordu.
public final class SystemStateReader {
    public static let shared = SystemStateReader()
    
    private let lock = NSLock()
    private var cachedValues: [String: String]?
    private var cachedAt: Date = .distantPast
    /// Aynı açılış/refresh turundaki okumalar tek çağrıyı paylaşsın diye kısa tutuldu.
    private let cacheLifetime: TimeInterval = 0.25
    
    private init() {}
    
    /// Verilen anahtarın son okunan değerini döndürür (yoksa boş string).
    public func value(for key: String) -> String {
        return snapshot()[key] ?? ""
    }
    
    /// Önbelleği arka planda tazeler; menü açılırken ilk kareyi bloklamaz.
    public func prewarmAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let isFresh = self.cachedValues != nil &&
                Date().timeIntervalSince(self.cachedAt) < self.cacheLifetime
            self.lock.unlock()
            if !isFresh {
                _ = self.snapshot()
            }
        }
    }
    
    /// Bir anahtar değiştirildikten sonra önbelleği geçersiz kılar.
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        cachedValues = nil
        cachedAt = .distantPast
    }
    
    private func snapshot() -> [String: String] {
        lock.lock()
        let now = Date()
        if let values = cachedValues, now.timeIntervalSince(cachedAt) < cacheLifetime {
            lock.unlock()
            return values
        }
        lock.unlock()
        
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
