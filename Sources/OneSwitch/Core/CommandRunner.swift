import Foundation

/// Sistem komutlarını ve AppleScript betiklerini güvenli bir şekilde çalıştıran yardımcı sınıf.
public final class CommandRunner {
    public static let shared = CommandRunner()
    
    private init() {}
    
    /// Belirtilen shell komutunu zsh üzerinden çalıştırır ve çıktıyı döndürür.
    @discardableResult
    public func runShell(_ command: String) -> (output: String, exitCode: Int32) {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (output, task.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
    
    /// AppleScript kodunu çalıştırır ve sonucunu döndürür.
    @discardableResult
    public func runAppleScript(_ script: String) -> (success: Bool, output: String) {
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let error = error {
                let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Bilinmeyen AppleScript hatası"
                return (false, errorMsg)
            }
            return (true, result.stringValue ?? "")
        }
        return (false, "AppleScript nesnesi oluşturulamadı")
    }
}
