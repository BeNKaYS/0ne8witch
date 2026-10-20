import SwiftUI
import AppKit

/// Uygulamanın ortak renkleri.
///
/// Aktif öğeler her yerde aynı turuncu ile gösterilir. Renk, sistem görünümüne
/// göre değişir: karanlık modda parlak turuncu, aydınlık modda daha koyu turuncu.
/// Böylece hem ikon hem de küçük durum yazıları iki temada da okunabilir kalır.
public enum AppTheme {
    public static let active = Color(nsColor: NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            // Karanlık zemin için parlak turuncu
            return NSColor(calibratedRed: 1.00, green: 0.64, blue: 0.10, alpha: 1.0)
        }
        // Aydınlık zemin için kontrastı yüksek koyu turuncu
        return NSColor(calibratedRed: 0.72, green: 0.36, blue: 0.00, alpha: 1.0)
    })

    /// Aktif ikon kutusunun arka planı
    public static let activeBackground = active.opacity(0.16)
}
