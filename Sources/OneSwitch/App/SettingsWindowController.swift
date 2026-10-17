import AppKit
import SwiftUI

/// macOS Ayarlar Penceresini yöneten tekil pencere denetleyicisi
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// Ayarlar penceresini açar veya öne getirir
    public func showSettings() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.closePopover()
        }
        
        if let existingWindow = window {
            bringToFront(existingWindow)
            return
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "0ne8witch Ayarları"
        newWindow.contentMinSize = NSSize(width: 600, height: 540)
        newWindow.center()
        newWindow.setFrameAutosaveName("0ne8witchSettingsWindow")
        newWindow.contentViewController = NSHostingController(rootView: SettingsView())
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        
        self.window = newWindow
        bringToFront(newWindow)
    }
    
    /// Pencereyi etkin alanda ve diğer pencerelerin arkasında kalmayacak şekilde öne getirir.
    /// (Menü çubuğu uygulamaları arka planda kalabildiği için önce uygulama etkinleştirilir.)
    private func bringToFront(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior.insert(.moveToActiveSpace)
        NSApp.bringAppForward()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
    
    public func close() {
        window?.close()
    }
    
    public func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
