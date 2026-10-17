import AppKit
import SwiftUI

/// Ekranı ve klavyeyi temizlerken tıklamaları engelleyen tam ekran karartma penceresi
public final class ScreenCleanOverlayWindow: NSWindow {
    private var dismissTimer: Timer?
    private var escPressDuration: Double = 0
    private var isDismissing = false
    public var onDismiss: (() -> Void)?
    
    public init() {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = true
        self.backgroundColor = .black
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = false
        
        let hostingView = NSHostingView(rootView: ScreenCleanView(onExit: { [weak self] in
            self?.closeCleanMode()
        }))
        self.contentView = hostingView
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        // ESC tuşu basıldığında
        if event.keyCode == 53 {
            closeCleanMode()
        }
    }
    
    private func closeCleanMode() {
        guard !isDismissing else { return }
        isDismissing = true
        self.orderOut(nil)
        onDismiss?()
    }
}

/// Ekran Temizleme ekranının SwiftUI arayüzü
public struct ScreenCleanView: View {
    public let onExit: () -> Void
    
    public var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.white.opacity(0.85))
                
                Text("Ekran Temizleme Modu")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Ekranınızı ve klavyenizi güvenle temizleyebilirsiniz.\nTüm tuş vuruşları ve tıklamalar engellendi.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Button(action: onExit) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Temizleme Modundan Çık (veya ESC tuşuna basın)")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
