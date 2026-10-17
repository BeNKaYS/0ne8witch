#!/bin/bash
set -e

echo "🚀 OneSwitch TR derleniyor (Release)..."
cd "$(dirname "$0")"

swift build -c release

APP_NAME="OneSwitch"
BUNDLE_DIR="$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

echo "📦 Uygulama paketi (.app) oluşturuluyor..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# İkili dosyayı kopyala (SwiftPM ürün adı: 0ne8witch)
cp ".build/release/0ne8witch" "$MACOS_DIR/$APP_NAME"

# Kaynakları kopyala (Geliştirici Kartı, İkonlar, JS)
if [ -d "Sources/OneSwitch/Resources" ]; then
    cp -R Sources/OneSwitch/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Info.plist oluştur
cat << 'EOF' > "$BUNDLE_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OneSwitch</string>
    <key>CFBundleIdentifier</key>
    <string>com.avenox.oneswitch</string>
    <key>CFBundleName</key>
    <string>OneSwitch TR</string>
    <key>CFBundleDisplayName</key>
    <string>OneSwitch TR</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Telif Hakkı © 2026. Tüm hakları saklıdır.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>OneSwitch sistem ayarlarını (Karanlık Mod, Dock vb.) kontrol etmek için AppleEvents erişimi gerektirir.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>OneSwitch masaüstü simgelerini yönetmek için masaüstü erişimi gerektirir.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>OneSwitch harici disklerdeki çöp kutularını temizlemek için disk erişimi gerektirir.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>OneSwitch sistem temizleme ve güç yönetimi için yönetici erişimi gerektirir.</string>
</dict>
</plist>
EOF

# Çalıştırma izinlerini ayarla
chmod +x "$MACOS_DIR/$APP_NAME"

echo "✅ Başarılı! $BUNDLE_DIR hazırlandı."
echo "👉 Çalıştırmak için: open $BUNDLE_DIR veya ./$BUNDLE_DIR/Contents/MacOS/OneSwitch"
