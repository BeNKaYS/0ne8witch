import AppKit
import SwiftUI

/// Menüden açılan yardımcı paneller için tek pencere yöneticisi.
///
/// Her panel kendi kimliğiyle açılır: aynı panel ikinci kez istenirse yeni
/// pencere açılmaz, mevcut pencere öne getirilir. Menü çubuğu uygulaması
/// olduğumuz için pencere `floating` seviyesinde açılır ve uygulama öne alınır.
@MainActor
public final class PanelWindow {
    public static let shared = PanelWindow()

    private var windows: [String: NSWindow] = [:]

    private init() {}

    public func show<Content: View>(
        id: String,
        title: String,
        width: CGFloat,
        height: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = content()
            .frame(width: width, height: height)
            .background(Color(nsColor: .windowBackgroundColor))

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: width, height: height))
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.center()
        window.titlebarAppearsTransparent = false

        windows[id] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.windows[id] = nil
            }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
