import SwiftUI

/// Popover içerisinde gösterilen ana 0ne8witch arayüzü
public struct MainMenuView: View {
    @ObservedObject var manager = SwitchManager.shared
    @ObservedObject var prefs = PreferencesManager.shared

    @State private var query = ""
    @State private var category: SwitchCategory = .all

    public init() {}

    /// Arama ve kategoriye göre süzülmüş görünür anahtarlar.
    private var items: [any SwitchItemProtocol] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return manager.filteredSwitches.filter { item in
            (category == .all || item.category == category) &&
            (q.isEmpty
             || item.title.localizedCaseInsensitiveContains(q)
             || item.subtitle.localizedCaseInsensitiveContains(q))
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            FilterBar(query: $query, category: $category)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider().opacity(0.6)

            // Anahtar Listesi
            ScrollView {
                LazyVStack(spacing: 2) {
                    let list = items
                    if list.isEmpty {
                        EmptyStateView(isSearching: !query.isEmpty || category != .all)
                    } else {
                        ForEach(list, id: \.id) { item in
                            SwitchRowView(item: item)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(height: 340)

            // Hızlı Eylemler (hiçbiri seçili değilse bölüm gizlenir)
            if !prefs.visibleQuickActions.isEmpty {
                Divider().opacity(0.6)
                QuickActionsBar()
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 340)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
        // Bildirim yerleşimi kaydırmaz, altta yüzer.
        .overlay(alignment: .bottom) {
            NotificationBanner()
                .padding(.bottom, 10)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: manager.statusNotification)
        }
    }
}

/// Arama alanı ve kategori çipleri
private struct FilterBar: View {
    @Binding var query: String
    @Binding var category: SwitchCategory
    @ObservedObject private var manager = SwitchManager.shared

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Anahtar ara", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Aramayı temizle")
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )

            HStack(spacing: 4) {
                ForEach(SwitchCategory.allCases) { cat in
                    CategoryChip(
                        title: cat.shortName,
                        activeCount: activeCount(cat),
                        isSelected: category == cat
                    ) {
                        category = cat
                    }
                }
            }
        }
    }

    private func activeCount(_ cat: SwitchCategory) -> Int {
        manager.filteredSwitches.filter { $0.isOn && (cat == .all || $0.category == cat) }.count
    }
}

private struct CategoryChip: View {
    let title: String
    let activeCount: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .foregroundColor(isSelected ? AppTheme.active : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .foregroundColor(isSelected ? .primary : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                          ? Color.primary.opacity(0.10)
                          : Color.primary.opacity(hovering ? 0.05 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct EmptyStateView: View {
    let isSearching: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isSearching ? "magnifyingglass" : "eye.slash")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(.secondary)
            Text(isSearching ? "Eşleşen anahtar yok" : "Gösterilecek anahtar yok")
                .font(.system(size: 12, weight: .medium))
            Text(isSearching
                 ? "Farklı bir kelime veya kategori deneyin."
                 : "Ayarlar › Anahtarları Özelleştir'den açabilirsiniz.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// macOS Yerel Bulanıklık (Vibrancy) Arka Planı
public struct VisualEffectView: NSViewRepresentable {
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
