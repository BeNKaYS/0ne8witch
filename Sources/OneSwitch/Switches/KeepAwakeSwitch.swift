import Foundation
import SwiftUI
import Combine

/// Mac'in uyku moduna geçmesini engelleyen Uyanık Kal anahtarı (caffeinate tabanlı)
public final class KeepAwakeSwitch: ObservableObject, SwitchItemProtocol {
    public let id = "keep_awake"
    public let title = "Uyanık Kal"
    public let iconName = "cup.and.saucer.fill"
    public let activeColor = Color.orange
    public let category = SwitchCategory.system
    public let hasOptions = true
    
    @Published public var isOn: Bool = false
    @Published public var subtitle: String = "Normal Uyku Modu"
    @Published public var selectedDuration: DurationOption = .indefinite
    @Published public var remainingSeconds: Int = 0
    
    public enum DurationOption: String, CaseIterable, Identifiable {
        case indefinite = "Süresiz"
        case m15 = "15 Dakika"
        case m30 = "30 Dakika"
        case h1 = "1 Saat"
        case h2 = "2 Saat"
        
        public var id: String { rawValue }
        
        public var seconds: Int {
            switch self {
            case .indefinite: return 0
            case .m15: return 15 * 60
            case .m30: return 30 * 60
            case .h1: return 60 * 60
            case .h2: return 120 * 60
            }
        }
    }
    
    private var caffeinateProcess: Process?
    private var timer: Timer?
    
    public init() {
        refresh()
    }
    
    public func toggle() {
        if isOn {
            turnOff()
        } else {
            turnOn(duration: selectedDuration)
        }
    }
    
    public func turnOn(duration: DurationOption) {
        turnOff() // Mevcut varsa temizle
        
        selectedDuration = duration
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        
        if duration.seconds > 0 {
            task.arguments = ["-d", "-i", "-m", "-t", "\(duration.seconds)"]
            remainingSeconds = duration.seconds
            startTimer()
        } else {
            task.arguments = ["-d", "-i", "-m"]
            subtitle = "Süresiz Uyanık"
        }
        
        do {
            try task.run()
            self.caffeinateProcess = task
            self.isOn = true
            if duration.seconds > 0 {
                updateSubtitleForRemaining()
            }
        } catch {
            self.isOn = false
            self.subtitle = "Hata oluştu"
        }
    }
    
    public func turnOff() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
        
        if let process = caffeinateProcess, process.isRunning {
            process.terminate()
        }
        caffeinateProcess = nil
        
        // Sistemde kalan yetim caffeinate süreçlerini sonlandır
        CommandRunner.shared.runShell("killall caffeinate 2>/dev/null")
        
        self.isOn = false
        self.subtitle = "Normal Uyku Modu"
    }
    
    public func refresh() {
        // Sistemde çalışan caffeinate var mı kontrol et
        let hasCaffeinate = !SystemStateReader.shared.value(for: "Caffeinate").isEmpty
        if hasCaffeinate {
            if !isOn {
                self.isOn = true
                self.subtitle = "Uyanık (Etkin)"
            }
        } else {
            if isOn && caffeinateProcess == nil {
                self.isOn = false
                self.subtitle = "Normal Uyku Modu"
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                self.updateSubtitleForRemaining()
            } else {
                self.turnOff()
            }
        }
    }
    
    private func updateSubtitleForRemaining() {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        subtitle = String(format: "%02d:%02d kaldı", mins, secs)
    }
}
