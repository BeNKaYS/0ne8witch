import SwiftUI

/// Her bir anahtarın macOS Kontrol Merkezi tarzındaki satır görünümü
public struct SwitchRowView: View {
    let item: any SwitchItemProtocol
    @ObservedObject private var manager = SwitchManager.shared
    @State private var hovering = false

    public init(item: any SwitchItemProtocol) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: 10) {
            // İkon: açıkken dolu vurgu rengi, kapalıyken nötr
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.isOn ? AppTheme.active : Color.primary.opacity(0.07))
                Image(systemName: item.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(item.isOn ? .white : .secondary)
            }
            .frame(width: 28, height: 28)
            .animation(.easeOut(duration: 0.15), value: item.isOn)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let brightness = item as? BrightnessSwitch {
                Slider(
                    value: Binding(
                        get: { brightness.level },
                        set: { brightness.setLevel($0) }
                    ),
                    in: 0...1
                )
                .frame(width: 74)
                .controlSize(.mini)
                .tint(AppTheme.active)
            }

            if let keepAwake = item as? KeepAwakeSwitch {
                KeepAwakeMenu(keepAwake: keepAwake)
            }

            Toggle("", isOn: Binding(
                get: { item.isOn },
                set: { _ in
                    // Sonraki okuma eski önbelleği görmesin.
                    SystemStateReader.shared.invalidate()
                    item.toggle()
                }
            ))
            .toggleStyle(.switch)
            .tint(AppTheme.active)
            .labelsHidden()
            .controlSize(.mini)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(hovering ? 0.06 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .help(item.subtitle)
    }
}

/// Uyanık Kal için süre seçimi
private struct KeepAwakeMenu: View {
    @ObservedObject var keepAwake: KeepAwakeSwitch

    var body: some View {
        Menu {
            ForEach(KeepAwakeSwitch.DurationOption.allCases) { option in
                Button {
                    keepAwake.turnOn(duration: option)
                } label: {
                    if keepAwake.selectedDuration == option && keepAwake.isOn {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
            if keepAwake.isOn {
                Divider()
                Button("Durdur") { keepAwake.turnOff() }
            }
        } label: {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(keepAwake.isOn ? AppTheme.active : .secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Süre seç")
    }
}
