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
    /// Bir onceki kurulum denemesinin sonucu (uygulama yeniden basladiginda okunur).
    @Published public var lastInstallResult: String? = nil

    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private let defaults = UserDefaults.standard
    private let kFeedURL = "kUpdateFeedURL"
    private let kLastChecked = "kUpdateLastChecked"
    private let kLocalUpdateDir = "kLocalUpdateDirectory"
    private let defaultFeedURL = "https://api.github.com/repos/BeNKaYS/0ne8witch/releases/latest"

    @Published public var feedURL: String = "" {
        didSet { defaults.set(feedURL, forKey: kFeedURL) }
    }

    /// Yerel guncelleme paketlerinin aranacagi klasor.
    @Published public var localUpdateDirectory: String = NSString(string: "~/Downloads").expandingTildeInPath {
        didSet { defaults.set(localUpdateDirectory, forKey: kLocalUpdateDir) }
    }

    private var downloadTask: URLSessionDownloadTask?
    private var downloadedZipURL: URL?
    private var extractedAppURL: URL?
    /// Kurulacak surumun etiketi; kurulum gunlugune yazilir.
    private var installTargetVersion: String = ""

    /// Kurulum gunlugunun yolu. Uygulama kurulum sirasinda kapandigi icin
    /// sonuc ancak bir sonraki acilista okunabilir.
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("0ne8witch", isDirectory: true)
    }

    static var installLogURL: URL {
        supportDirectory.appendingPathComponent("update.log")
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
        feedURL = defaults.string(forKey: kFeedURL) ?? defaultFeedURL
        if let ts = defaults.object(forKey: kLastChecked) as? Double {
            lastChecked = Date(timeIntervalSince1970: ts)
        }
        if let dir = defaults.string(forKey: kLocalUpdateDir), !dir.isEmpty {
            localUpdateDirectory = dir
        }
        readInstallResult()
    }

    /// Onceki kurulum denemesinin sonucunu gunlukten okur ve gunlugu temizler.
    private func readInstallResult() {
        let url = UpdateManager.installLogURL
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let last = lines.last else { return }

        // Bicim: tarih|surum|sonuc
        let parts = last.split(separator: "|", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return }
        let version = parts[1]
        let result = parts[2]
        let label = version.isEmpty ? "Guncelleme" : "Surum \(version)"
        if result.hasPrefix("ok") {
            lastInstallResult = "\(label) basariyla kuruldu."
        } else if result.hasPrefix("fail") {
            let reason = result.replacingOccurrences(of: "fail:", with: "").trimmingCharacters(in: .whitespaces)
            lastInstallResult = "\(label) kurulamadi. \(reason)"
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
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.handleResponse(data: data, url: url, status: status)
            }
        }
        task.resume()
    }

    private func handleResponse(data: Data, url: URL, status: Int) {
        if url.absoluteString.contains("api.github.com") {
            if status == 200 {
                parseGitHubRelease(data: data)
                return
            }
            // GitHub API'si kimlik dogrulama olmadan saatte 60 istekle sinirli.
            // Sinir doldugunda API 403 doner; bu durumda surum bilgisi herkese
            // acik Atom akisindan okunur ve indirme baglantisi oradan kurulur.
            let reason: String
            switch status {
            case 403, 429:
                reason = "GitHub API istek limiti doldu"
            case 404:
                reason = "GitHub deposu bulunamadi veya herkese acik degil"
            default:
                reason = "GitHub API yaniti: HTTP \(status)"
            }
            if let repo = Self.githubRepo(from: url) {
                checkViaAtom(repo: repo, reason: reason)
            } else {
                state = .error("\(reason). Guncelleme adresini kontrol edin veya yerel dosyadan guncelleyin.")
            }
        } else {
            guard status == 200 else {
                state = .error("Guncelleme sunucusu HTTP \(status) dondurdu.")
                return
            }
            parseManifest(data: data)
        }
    }

    private func parseGitHubRelease(data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                state = .error("Gecersiz JSON.")
                return
            }
            if let message = json["message"] as? String, json["tag_name"] == nil {
                state = .error("GitHub: \(message)")
                return
            }
            let tag = (json["tag_name"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
            let notes = json["body"] as? String ?? ""

            var zipAsset: [String: Any]?
            if let assets = json["assets"] as? [[String: Any]] {
                zipAsset = assets.first(where: {
                    ($0["name"] as? String ?? "").lowercased().hasSuffix(".zip")
                })
            }
            guard let downloadURL = zipAsset?["browser_download_url"] as? String else {
                state = .error("Release'te (.zip) paket yok. GitHub Releases bolumune .zip yukleyin veya yerel dosyadan guncelleyin.")
                return
            }

            finishCheck(version: version, notes: notes, downloadURL: downloadURL)
        } catch {
            state = .error("JSON ayristirma hatasi: \(error.localizedDescription)")
        }
    }

    /// API siniri doldugunda kullanilan yedek yol: herkese acik Atom akisindan
    /// son surum etiketi, surum sayfasindan da .zip baglantisi okunur.
    private func checkViaAtom(repo: String, reason: String) {
        guard let url = URL(string: "https://github.com/\(repo)/releases.atom") else {
            state = .error("\(reason). Guncelleme adresi okunamadi.")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("0ne8witch/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard error == nil, status == 200,
                      let data = data,
                      let body = String(data: data, encoding: .utf8),
                      let tag = Self.latestAtomTag(body) else {
                    self.state = .error("\(reason). Yedek kaynaktan da surum bilgisi alinamadi. Yerel dosyadan guncelleyin.")
                    return
                }
                self.checkAssets(repo: repo, tag: tag, reason: reason)
            }
        }.resume()
    }

    private func checkAssets(repo: String, tag: String, reason: String) {
        guard let encodedTag = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://github.com/\(repo)/releases/expanded_assets/\(encodedTag)") else {
            state = .error("\(reason). Surum sayfasi adresi olusturulamadi.")
            return
        }
        var request = URLRequest(url: url)
        request.setValue("0ne8witch/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard error == nil, status == 200,
                      let data = data,
                      let html = String(data: data, encoding: .utf8),
                      let href = Self.firstZipHref(in: html) else {
                    self.state = .error("Release'te (.zip) paket yok. GitHub Releases bolumune .zip yukleyin veya yerel dosyadan guncelleyin.")
                    return
                }
                let absolute = href.hasPrefix("http") ? href : "https://github.com\(href)"
                let version = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
                self.finishCheck(version: version, notes: "", downloadURL: absolute)
            }
        }.resume()
    }

    /// "owner/repo" bilgisini GitHub API adresinden cikarir.
    static func githubRepo(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let index = parts.firstIndex(of: "repos"),
              parts.count > index + 2 else { return nil }
        return "\(parts[index + 1])/\(parts[index + 2])"
    }

    /// Atom akisindaki ilk surumun etiketini dondurur ("v1.0.1" gibi).
    static func latestAtomTag(_ xml: String) -> String? {
        guard let entryRange = xml.range(of: "<entry>") else { return nil }
        let entry = String(xml[entryRange.lowerBound...])
        guard let title = firstCapture(#"<title>([^<]+)</title>"#, in: entry) else { return nil }
        let tag = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag.isEmpty ? nil : tag
    }

    /// Surum sayfasindaki ilk .zip baglantisini dondurur.
    /// Kaynak kod arsivi yerine yuklenmis paket tercih edilir.
    static func firstZipHref(in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"href="([^"]+\.zip)""#, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let hrefs: [String] = regex.matches(in: html, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[r])
        }
        return hrefs.first(where: { $0.contains("/releases/download/") }) ?? hrefs.first
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let matchRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[matchRange])
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
        guard canWriteToAppFolder() else { return }
        state = .installing
        if installTargetVersion.isEmpty { installTargetVersion = latestVersion }

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

    /// Uygulama klasorune yazma izni yoksa kurulumu baslatmadan anlasilir bir hata verir.
    /// Aksi halde uygulama kapanir, kurulum sessizce basarisiz olur ve kullanici
    /// hicbir sey olmamis gibi gorur.
    private func canWriteToAppFolder() -> Bool {
        let fm = FileManager.default
        let appPath = Bundle.main.bundlePath
        let folder = (appPath as NSString).deletingLastPathComponent

        if !fm.isWritableFile(atPath: folder) {
            state = .error("\(folder) klasorune yazma izni yok. Guncellemeyi uygulamayi kapatip elle kurun veya .pkg yukleyicisini kullanin.")
            return false
        }
        if fm.fileExists(atPath: appPath), !fm.isWritableFile(atPath: appPath) {
            state = .error("Uygulama dosyasi salt okunur (\(appPath)). Yonetici izniyle guncelleyin.")
            return false
        }
        return true
    }

    /// Yerel olarak secilen bir .zip veya .app dosyasindan guncelleme kurar.
    public func installLocalPackage(from url: URL) {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip":
            downloadURL = nil
            installTargetVersion = Self.versionOfZip(at: url) ?? ""
            downloadedZipURL = url
            installUpdate()
        case "app":
            let fm = FileManager.default
            installTargetVersion = Self.versionOfApp(at: url) ?? url.deletingPathExtension().lastPathComponent
            guard canWriteToAppFolder() else { return }
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

    static func versionOfApp(at url: URL) -> String? {
        let plist = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        let version = dict["CFBundleShortVersionString"] as? String
        let build = dict["CFBundleVersion"] as? String
        if let v = version, let b = build { return "\(v) (build \(b))" }
        return version
    }

    /// Zip icindeki .app paketinin surumunu okur; okunamazsa nil doner.
    static func versionOfZip(at url: URL) -> String? {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("0ne8witch-probe-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        guard (try? fm.createDirectory(at: tmp, withIntermediateDirectories: true)) != nil else { return nil }

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", "-o", url.path, "*.app/Contents/Info.plist", "-d", tmp.path]
        unzip.standardError = FileHandle.nullDevice
        unzip.standardOutput = FileHandle.nullDevice
        guard (try? unzip.run()) != nil else { return nil }
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else { return nil }

        guard let enumerator = fm.enumerator(at: tmp, includingPropertiesForKeys: nil) else { return nil }
        for case let item as URL in enumerator where item.lastPathComponent == "Info.plist" {
            guard let data = try? Data(contentsOf: item),
                  let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { continue }
            if let v = dict["CFBundleShortVersionString"] as? String {
                if let b = dict["CFBundleVersion"] as? String { return "\(v) (build \(b))" }
                return v
            }
        }
        return nil
    }

    /// Yerel guncelleme klasorundeki .zip/.app paketlerini, en yeniden eskiye dogru listeler.
    public func localUpdateCandidates(limit: Int = 10) -> [URL] {
        let fm = FileManager.default
        let expanded = NSString(string: localUpdateDirectory).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: expanded, isDirectory: &isDirectory) else { return [] }

        let root = URL(fileURLWithPath: expanded)
        let supportedExtensions = ["zip", "app"]

        // Adres dogrudan bir paket dosyasini gosteriyorsa onu dondur.
        if !isDirectory.boolValue {
            return supportedExtensions.contains(root.pathExtension.lowercased()) ? [root] : []
        }

        guard let items = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { modificationDate(of: $0) > modificationDate(of: $1) }
            .prefix(limit)
            .map { $0 }
    }

    private func modificationDate(of url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }

    /// Verilen .app paketini mevcut uygulamanin uzerine kurar ve yeniden baslatir.
    /// Kurulumdan once mevcut uygulama yedeklenir; tasima veya acilis basarisiz
    /// olursa yedekten geri donulur.
    private func installFromApp(at appURL: URL) {
        let fm = FileManager.default
        let currentAppPath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let newAppPath = appURL.path
        let target = installTargetVersion.isEmpty ? latestVersion : installTargetVersion
        let script = """
        #!/bin/bash
        APP_PATH=\(shellQuote(currentAppPath))
        NEW_APP=\(shellQuote(newAppPath))
        PID=\(pid)
        TARGET_VERSION=\(shellQuote(target))
        SUPPORT_DIR="$HOME/Library/Application Support/0ne8witch"
        BACKUP_DIR="$SUPPORT_DIR/backups"
        LOG="$SUPPORT_DIR/update.log"
        mkdir -p "$BACKUP_DIR"

        log_result() {
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|$TARGET_VERSION|$1" >> "$LOG"
        }

        while kill -0 $PID 2>/dev/null; do sleep 0.5; done

        BACKUP="$BACKUP_DIR/0ne8witch-$(date +%Y%m%d-%H%M%S).zip"
        HAVE_BACKUP=0
        if [ -d "$APP_PATH" ] && /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$BACKUP"; then
            HAVE_BACKUP=1
        fi

        restore() {
            if [ "$HAVE_BACKUP" = "1" ]; then
                TMP=$(mktemp -d)
                if /usr/bin/ditto -x -k "$BACKUP" "$TMP"; then
                    OLD_APP=$(find "$TMP" -maxdepth 2 -name "*.app" | head -n 1)
                    rm -rf "$APP_PATH"
                    if [ -n "$OLD_APP" ]; then mv "$OLD_APP" "$APP_PATH"; fi
                    rm -rf "$TMP"
                    open "$APP_PATH"
                fi
            fi
        }

        if [ ! -d "$NEW_APP" ]; then
            log_result "fail: gecici kopya bulunamadi"
            restore
            exit 1
        fi

        rm -rf "$APP_PATH"
        if ! mv "$NEW_APP" "$APP_PATH"; then
            log_result "fail: dosyalar tasinamadi (izin?)"
            restore
            exit 1
        fi
        xattr -cr "$APP_PATH" 2>/dev/null || true
        if ! open "$APP_PATH"; then
            log_result "fail: uygulama acilamadi"
            restore
            exit 1
        fi
        log_result "ok"
        # En yeni 3 yedek kalsin
        ls -1t "$BACKUP_DIR"/0ne8witch-*.zip 2>/dev/null | tail -n +4 | while read -r f; do rm -rf "$f"; done
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
