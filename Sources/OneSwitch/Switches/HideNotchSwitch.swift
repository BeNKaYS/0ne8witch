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

    /// Menü çubuğu altındaki sol/sağ köşelerin yuvarlatma yarıçapı.
    /// Pencere köşe yarıçapından büyük olmalı ki köşe boşlukları tam kapansın.
    private static let cornerRadius: CGFloat = 22

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
            // Altına içbükey köşeler için `cornerRadius` kadar ek alan bırakılır.
            let r = HideNotchSwitch.cornerRadius
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - height - r,
                width: screen.frame.width,
                height: height + r
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
            window.backgroundColor = .clear
            window.isOpaque = false
            window.animationBehavior = .none

            window.contentView = NotchMaskView(
                frame: NSRect(origin: .zero, size: frame.size),
                cornerRadius: r
            )

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

/// Üstte düz siyah şerit, altında sol ve sağda içbükey siyah köşeler çizer.
private final class NotchMaskView: NSView {
    private let r: CGFloat

    init(frame: NSRect, cornerRadius: CGFloat) {
        r = cornerRadius
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmaz") }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        let w = bounds.width
        // Menü çubuğu şeridi
        NSRect(x: 0, y: r, width: w, height: bounds.height - r).fill()

        // Sol köşe: kare eksi çeyrek daire
        let left = NSBezierPath()
        left.move(to: NSPoint(x: 0, y: 0))
        left.line(to: NSPoint(x: 0, y: r))
        left.line(to: NSPoint(x: r, y: r))
        left.appendArc(withCenter: NSPoint(x: r, y: 0), radius: r, startAngle: 90, endAngle: 180)
        left.close()
        left.fill()

        // Sağ köşe
        let right = NSBezierPath()
        right.move(to: NSPoint(x: w, y: 0))
        right.line(to: NSPoint(x: w, y: r))
        right.line(to: NSPoint(x: w - r, y: r))
        right.appendArc(withCenter: NSPoint(x: w - r, y: 0), radius: r, startAngle: 90, endAngle: 0, clockwise: true)
        right.close()
        right.fill()
    }
}

/// Menü çubuğunun arkasına yerleşen, klavye odağı almayan sessiz pencere.
private final class NotchMaskWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
