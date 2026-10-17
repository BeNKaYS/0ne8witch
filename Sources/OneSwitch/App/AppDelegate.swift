import AppKit
import SwiftUI

extension NSApplication {
    /// Uygulamayı öne getirir (menü çubuğu uygulamaları için gerekli)
    func bringAppForward() {
        if #available(macOS 14.0, *) {
            self.activate()
        } else {
            self.activate(ignoringOtherApps: true)
        }
    }
}

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Menü Çubuğu Öğesi Oluştur
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateStatusItemIcon(name: PreferencesManager.shared.menuBarIcon)
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Simge değiştiğinde menü çubuğunu güncelle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIconChange(_:)),
            name: .menuBarIconDidChange,
            object: nil
        )
        
        // Popover Oluştur
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainMenuView())
        
        // İlk açılışta durumları tara
        SwitchManager.shared.refreshAll()
        
        // Canlı Sistem Monitörünü Başlat (CPU & RAM)
        SystemMonitor.shared.startMonitoring()
        
        // Dışarı tıklandığında popover'ı kapatmak için global event monitor
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            if self.popover.isShown {
                self.closePopover()
            }
        }
    }
    
    @objc private func handleIconChange(_ notification: Notification) {
        if let iconName = notification.object as? String {
            updateStatusItemIcon(name: iconName)
        }
    }
    
    private func updateStatusItemIcon(name: String) {
        guard let button = statusItem?.button else { return }
        
        if name == "AppLogo" {
            var customImg: NSImage?
            if let imgURL = Bundle.main.url(forResource: "app_icon", withExtension: "png") {
                customImg = NSImage(contentsOf: imgURL)
            } else if let localImg = NSImage(contentsOfFile: "Sources/OneSwitch/Resources/app_icon.png") {
                customImg = localImg
            } else if let bundleIcon = NSImage(named: "AppIcon") {
                customImg = bundleIcon
            }
            
            if let img = customImg {
                img.size = NSSize(width: 18, height: 18)
                button.image = img
                return
            }
        }
        
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "0ne8witch")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
    }
    
    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem.button else { return }
        SwitchManager.shared.refreshAll()
        // Menü başka uygulamaların arkasında kalmasın
        NSApp.bringAppForward()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    
    public func closePopover() {
        popover.performClose(nil)
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        // Canlı Sistem Monitörünü Durdur
        SystemMonitor.shared.stopMonitoring()
        // Uyanık kal aktifse temizle
        SwitchManager.shared.keepAwake.turnOff()
    }
}
