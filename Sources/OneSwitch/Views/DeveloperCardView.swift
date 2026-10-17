import SwiftUI
import WebKit

/// Sercan Özdemir (BeNKaYS) Geliştirici Kartını görüntüleyen WebKit bileşeni
public struct DeveloperCardView: NSViewRepresentable {
    public init() {}
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        
        // 1. Bundle içinden dene
        var loaded = false
        if let bundleHTMLURL = Bundle.main.url(forResource: "developer_card", withExtension: "html"),
           let htmlContent = try? String(contentsOf: bundleHTMLURL, encoding: .utf8) {
            webView.loadHTMLString(htmlContent, baseURL: Bundle.main.resourceURL)
            loaded = true
        }
        
        // 2. Proje dizini fallback dene
        if !loaded {
            let possiblePaths = [
                "Sources/OneSwitch/Resources/developer_card.html",
                "../Resources/developer_card.html",
                "OneSwitch.app/Contents/Resources/developer_card.html",
                "0ne8witch.app/Contents/Resources/developer_card.html"
            ]
            
            for path in possiblePaths {
                let fileURL = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                    webView.loadHTMLString(content, baseURL: fileURL.deletingLastPathComponent())
                    loaded = true
                    break
                }
            }
        }
        
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {}
    
    public final class Coordinator: NSObject, WKNavigationDelegate {
        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Tıklanan dış bağlantıları (GitHub, mailto, whatsapp) sistem tarayıcısında aç
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
