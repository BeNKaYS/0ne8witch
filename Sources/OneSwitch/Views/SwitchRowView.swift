import SwiftUI

/// Her bir anahtarın modern, macOS tarzındaki satır görünümü
public struct SwitchRowView: View {
    let item: any SwitchItemProtocol
    @ObservedObject private var manager = SwitchManager.shared
    
    public init(item: any SwitchItemProtocol) {
        self.item = item
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // İkon Kutusu
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.isOn ? AppTheme.activeBackground : Color.primary.opacity(0.06))
                    .frame(width: 34, height: 34)
                
                Image(systemName: item.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(item.isOn ? AppTheme.active : Color.secondary)
            }
            
            // Başlık ve Alt Durum
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(item.isOn ? AppTheme.active : .secondary)
            }
            
            Spacer()
            
            // Özel Seçenekler (Örn: Uyanık Kal için Süre Seçimi)
            if let keepAwake = item as? KeepAwakeSwitch {
                Menu {
                    ForEach(KeepAwakeSwitch.DurationOption.allCases) { option in
                        Button(action: {
                            keepAwake.turnOn(duration: option)
                        }) {
                            HStack {
                                Text(option.rawValue)
                                if keepAwake.selectedDuration == option && keepAwake.isOn {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if keepAwake.isOn {
                        Divider()
                        Button("Durdur") {
                            keepAwake.turnOff()
                        }
                    }
                } label: {
                    Image(systemName: "timer")
                        .font(.system(size: 13))
                        .foregroundColor(keepAwake.isOn ? AppTheme.active : .secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            
            // Toggle Anahtarı
            Toggle("", isOn: Binding(
                get: { item.isOn },
                set: { _ in
                    item.toggle()
                }
            ))
            .toggleStyle(.switch)
            .tint(AppTheme.active)
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(item.isOn ? AppTheme.active.opacity(0.07) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(item.isOn ? AppTheme.active.opacity(0.22) : Color.clear, lineWidth: 1)
        )
    }
}
