import Foundation
import SwiftUI
import Combine
import AppKit

/// Çentikli MacBook'larda menü çubuğu şeridini tek parça siyah yapar.
///
/// Kaplama, menü çubuğunun *üstüne* değil *arkasına* yerleştirilir
/// (masaüstü seviyesi). Menü çubuğu kendi yarı saydam zeminini bu siyah
/// katmanın üzerine çizer; böylece çentik ve iki yanı aynı renkte görünür,
/// menü çubuğu simgeleri ve saati etkilenmez.
public final class HideNotchSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "hide_notch"
    public let title = "Çentiği Gizle"
    public let iconName = "rectangle.topthird.inset.filled"
    public let activeColor = Color.gray
    public let category = SwitchCategory.display
    public let hasOptions = false

    private let kEnabled = "kHideNotchEnabled"

    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Çentik Görünür"

    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?

    public init() {
        if HideNotchSwitch.hasNotch, UserDefaults.standard.bool(forKey: kEnabled) {
            // Pencere kurulumu uygulama açılışında tamamlanmış olsun.
            DispatchQueue.main.async { [weak self] in
                self?.apply(true)
            }
        }
        refresh()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        removeOverlays()
    }

    /// Ekranın üstünde çentik (güvenli alan) var mı?
    public static var hasNotch: Bool {
        NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }
    }

    public func toggle() {
        guard HideNotchSwitch.hasNotch else {
            SwitchManager.shared.showNotification("Bu Mac'in ekranında çentik yok.")
            return
        }
        apply(!isOn)
    }

    public func refresh() {
        isOn = !windows.isEmpty
        if !HideNotchSwitch.hasNotch {
            subtitle = "Bu ekranda çentik yok"
        } else {
            subtitle = isOn ? "Çentik Gizli" : "Çentik Görünür"
        }
    }

    private func apply(_ enabled: Bool) {
        if enabled {
            installOverlays()
        } else {
            removeOverlays()
        }
        UserDefaults.standard.set(enabled, forKey: kEnabled)
        isOn = enabled
        subtitle = enabled ? "Çentik Gizli" : "Çentik Görünür"
    }

    // MARK: - Kaplama pencereleri

    /// Menü çubuğunun arkasında duran pencere seviyesi.
    /// Masaüstü simgelerinin hemen üstü, tüm uygulama pencerelerinin altı.
    private static let maskLevel = NSWindow.Level(
        rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1
    )

    private func installOverlays() {
        removeOverlays()

        // Menü çubuğu yüksekliği: çentik varsa güvenli alan, yoksa sistem değeri.
        let menuBarHeight = NSApplication.shared.mainMenu?.menuBarHeight ?? 0

        for screen in NSScreen.screens {
            let safeTop = screen.safeAreaInsets.top
            // Yalnızca çentikli (güvenli alanı olan) ekranlara uygula;
            // harici monitörlerde menü çubuğu görünümü değişmesin.
            guard safeTop > 0 else { continue }
            let height = max(safeTop, menuBarHeight)
            guard height > 0 else { continue }

            // Şeridin tamamı kaplanır: çentik, sol ve sağ yanlar tek parça siyah olur.
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - height,
                width: screen.frame.width,
                height: height
            )

            let window = NotchMaskWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.level = HideNotchSwitch.maskLevel
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.backgroundColor = .black
            window.isOpaque = true
            window.animationBehavior = .none

            let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            window.contentView = view

            window.orderFrontRegardless()
            windows.append(window)
        }

        // Ekran düzeni değişirse kaplamayı yenile.
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, self.isOn else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.installOverlays()
                }
            }
        }
    }

    private func removeOverlays() {
        windows.forEach {
            $0.orderOut(nil)
            $0.close()
        }
        windows.removeAll()
    }
}

/// Menü çubuğunun arkasına yerleşen, klavye odağı almayan sessiz pencere.
private final class NotchMaskWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
