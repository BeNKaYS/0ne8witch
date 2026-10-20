import Foundation
import Combine
import AppKit

public final class UpdateManager: NSObject, ObservableObject {
    public static let shared = UpdateManager()

    public enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, notes: String)
        case downloading(progress: Double)
        case readyToInstall
        case installing
        case error(String)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate),
                 (.readyToInstall, .readyToInstall), (.installing, .installing):
                return true
            case (.available(let a, let b), .available(let c, let d)):
                return a == c && b == d
            case (.downloading(let a), .downloading(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published public var state: State = .idle
    @Published public var latestVersion: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var lastChecked: Date?
    @Published public var downloadProgress: Double = 0

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let defaults = UserDefaults.standard
    private let kFeedURL = "kUpdateFeedURL"
    private let kLastChecked = "kUpdateLastChecked"
    private let defaultFeedURL = "https://api.github.com/repos/BeNKaYS/0ne8witch/releases/latest"

    public var feedURL: String {
        get { defaults.string(forKey: kFeedURL) ?? defaultFeedURL }
        set { defaults.set(newValue, forKey: kFeedURL) }
    }

    private var downloadTask: URLSessionDownloadTask?
    private var downloadedZipURL: URL?
    private var extractedAppURL: URL?

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
        if let ts = defaults.object(forKey: kLastChecked) as? Double {
            lastChecked = Date(timeIntervalSince1970: ts)
        }
    }

    public static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let aParts = a.split(separator: ".").map { Int($0) ?? 0 }
        let bParts = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av < bv { return .orderedAscending }
            if av > bv { return .orderedDescending }
        }
        return .orderedSame
    }

    public func checkForUpdates() {
        switch state {
        case .checking, .downloading, .installing: return
        default: break
        }
        state = .checking
        let urlString = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString) else {
            state = .error("Gecersiz guncelleme adresi.")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("0ne8witch/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    self.state = .error("Ag hatasi: \(error.localizedDescription)")
                    return
                }
                guard let data = data else {
                    self.state = .error("Veri alinamadi.")
                    return
                }
                self.handleResponse(data: data, url: url)
            }
        }
        task.resume()
    }

    private func handleResponse(data: Data, url: URL) {
        if url.absoluteString.contains("api.github.com") {
            parseGitHubRelease(data: data)
        } else {
            parseManifest(data: data)
        }
    }

    private func parseGitHubRelease(data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                state = .error("Gecersiz JSON.")
                return
            }
            let tag = (json["tag_name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
            let notes = json["body"] as? String ?? ""

            var downloadURL: String?
            if let assets = json["assets"] as? [[String: Any]] {
                let preferred = assets.first(where: { ($0["name"] as? String ?? "").lowercased().hasSuffix(".zip") })
                    ?? assets.first(where: { ($0["name"] as? String ?? "").lowercased().hasSuffix(".dmg") })
                    ?? assets.first(where: { ($0["name"] as? String ?? "").lowercased().hasSuffix(".pkg") })
                downloadURL = preferred?["browser_download_url"] as? String
            }
            if downloadURL == nil {
                state = .error("Release'te .zip dosyasi yok. GitHub Releases bolumune .zip yukleyin veya yerel dosyadan guncelleyin.")
                return
            }

            finishCheck(version: version, notes: notes, downloadURL: downloadURL!)
        } catch {
            state = .error("JSON ayristirma hatasi: \(error.localizedDescription)")
        }
    }

    private func parseManifest(data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                state = .error("Gecersiz manifest.")
                return
            }
            let version = json["version"] as? String ?? ""
            let downloadURL = json["downloadURL"] as? String ?? json["download_url"] as? String ?? ""
            let notes = json["notes"] as? String ?? json["releaseNotes"] as? String ?? ""
            if version.isEmpty || downloadURL.isEmpty {
                state = .error("Manifest eksik alan iceriyor.")
                return
            }
            finishCheck(version: version, notes: notes, downloadURL: downloadURL)
        } catch {
            state = .error("Manifest ayristirma hatasi: \(error.localizedDescription)")
        }
    }

    private func finishCheck(version: String, notes: String, downloadURL: String) {
        latestVersion = version
        releaseNotes = notes
        self.downloadURL = downloadURL
        lastChecked = Date()
        defaults.set(lastChecked!.timeIntervalSince1970, forKey: kLastChecked)

        if UpdateManager.compareVersions(version, currentVersion) == .orderedDescending {
            state = .available(version: version, notes: notes)
        } else {
            state = .upToDate
        }
    }

    private var downloadURL: String?

    public func downloadUpdate() {
        guard let urlString = downloadURL, let url = URL(string: urlString) else {
            state = .error("Indirme adresi yok.")
            return
        }
        state = .downloading(progress: 0)
        downloadProgress = 0

        let task = session.downloadTask(with: url)
        self.downloadTask = task
        task.resume()
    }

    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        state = .available(version: latestVersion, notes: releaseNotes)
    }

    public func installUpdate() {
        guard let zipURL = downloadedZipURL else {
            state = .error("Indirilen dosya bulunamadi.")
            return
        }
        state = .installing

        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("0ne8witch-update-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        } catch {
            state = .error("Cikarma dizini olusturulamadi: \(error.localizedDescription)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, workDir.path]
        let pipe = Pipe()
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            state = .error("Cikarma baslatilamadi: \(error.localizedDescription)")
            return
        }
        if process.terminationStatus != 0 {
            let errData = pipe.fileHandleForReading.readDataToEndOfFile()
            let err = String(data: errData, encoding: .utf8) ?? "Bilinmeyen hata"
            state = .error("Cikarma hatasi: \(err)")
            return
        }

        guard let appURL = findApp(in: workDir) else {
            state = .error("Guncelleme paketinde .app bulunamadi.")
            return
        }
        extractedAppURL = appURL
        installFromApp(at: appURL)
    }

    /// Yerel olarak secilen bir .zip veya .app dosyasindan guncelleme kurar.
    public func installLocalPackage(from url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip":
            downloadedZipURL = url
            installUpdate()
        case "app":
            let fm = FileManager.default
            let copyURL = fm.temporaryDirectory.appendingPathComponent("0ne8witch-local-\(UUID().uuidString).app")
            do {
                if fm.fileExists(atPath: copyURL.path) {
                    try fm.removeItem(at: copyURL)
                }
                try fm.copyItem(at: url, to: copyURL)
            } catch {
                state = .error("Yerel uygulama kopyalanamadi: \(error.localizedDescription)")
                return
            }
            extractedAppURL = copyURL
            state = .installing
            installFromApp(at: copyURL)
        default:
            state = .error("Desteklenmeyen dosya turu. .zip veya .app secin.")
        }
    }

    /// Verilen .app paketini mevcut uygulamanin uzerine kurar ve yeniden baslatir.
    private func installFromApp(at appURL: URL) {
        let fm = FileManager.default
        let currentAppPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let newAppPath = appURL.path
        let script = """
        #!/bin/bash
        APP_PATH=\(shellQuote(currentAppPath))
        NEW_APP=\(shellQuote(newAppPath))
        PID=\(pid)
        while kill -0 $PID 2>/dev/null; do sleep 0.5; done
        rm -rf "$APP_PATH"
        mv "$NEW_APP" "$APP_PATH"
        xattr -cr "$APP_PATH" 2>/dev/null || true
        open "$APP_PATH"
        """
        let scriptURL = fm.temporaryDirectory.appendingPathComponent("0ne8witch-install-\(UUID().uuidString).sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        } catch {
            state = .error("Kurulum betigi olusturulamadi: \(error.localizedDescription)")
            return
        }

        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
        launcher.arguments = [scriptURL.path]
        do {
            try launcher.run()
        } catch {
            state = .error("Kurulum baslatilamadi: \(error.localizedDescription)")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func findApp(in dir: URL) -> URL? {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "app" {
                    return url
                }
            }
        }
        return nil
    }

    private func shellQuote(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}

extension UpdateManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent("0ne8witch-update-\(UUID().uuidString).zip")
        do {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: location, to: dest)
            self.downloadedZipURL = dest
            DispatchQueue.main.async {
                self.state = .readyToInstall
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .error("Dosya kaydedilemedi: \(error.localizedDescription)")
            }
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }
        DispatchQueue.main.async {
            self.downloadProgress = progress
            if case .downloading = self.state {
                self.state = .downloading(progress: progress)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                if (error as NSError).code != NSURLErrorCancelled {
                    self.state = .error("Indirme hatasi: \(error.localizedDescription)")
                }
            }
        }
    }
}
