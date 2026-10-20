import SwiftUI

/// Popover içerisinde gösterilen ana OneSwitch arayüzü
public struct MainMenuView: View {
    @ObservedObject var manager = SwitchManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Başlık & Kategori Filtresi
            HeaderView()
            
            Divider()
                .padding(.vertical, 8)
            
            // Anahtar Listesi
            ScrollView {
                LazyVStack(spacing: 4) {
                    let items = manager.filteredSwitches
                    if items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.folder")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("Aramanızla eşleşen anahtar bulunamadı.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        ForEach(items, id: \.id) { item in
                            SwitchRowView(item: item)
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 340)
            
            Divider()
                .padding(.vertical, 6)
            
            // Hızlı Eylemler (Arama yoksa göster)
            if manager.searchText.isEmpty && manager.selectedCategory == .all {
                QuickActionsBar()
            }
            
            // Kısa süreli bilgilendirme
            if manager.statusNotification != nil {
                Divider()
                    .padding(.top, 4)
                NotificationBanner()
            }
        }
        .frame(width: 320)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
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
