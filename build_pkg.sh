#!/bin/bash
set -e

echo "🚀 0ne8witch Release modunda derleniyor..."
cd "$(dirname "$0")"

swift build -c release

APP_NAME="0ne8witch"
BUNDLE_DIR="$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

echo "📦 Uygulama paketi ($BUNDLE_DIR) hazırlanıyor..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# İkili dosyayı kopyala
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Kaynakları kopyala (Geliştirici Kartı, Avatar, JS)
if [ -d "Sources/OneSwitch/Resources" ]; then
    cp -R Sources/OneSwitch/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# İzinlerle donatılmış Info.plist oluştur
cat << 'EOF' > "$BUNDLE_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>0ne8witch</string>
    <key>CFBundleIdentifier</key>
    <string>com.avenox.0ne8witch</string>
    <key>CFBundleName</key>
    <string>0ne8witch</string>
    <key>CFBundleDisplayName</key>
    <string>0ne8witch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Telif Hakkı © 2026 Avenox. Tüm hakları saklıdır.</string>
    
    <!-- İzin Bildirimleri (Permissions) -->
    <key>NSAppleEventsUsageDescription</key>
    <string>0ne8witch, Çöp Kutusunu boşaltmak, sistem ayarlarını ve Finder'ı yönetmek için otomasyon izni gerektirir.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>0ne8witch masaüstü simgelerini yönetmek için masaüstü erişimi gerektirir.</string>
    <key>NSRemovableVolumesUsageDescription</key>
    <string>0ne8witch harici disklerdeki çöp kutularını temizlemek için disk erişimi gerektirir.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>0ne8witch sistem temizleme ve güç yönetimi için yönetici erişimi gerektirir.</string>
</dict>
</plist>
EOF

# Çalıştırma izinlerini ver
chmod +x "$MACOS_DIR/$APP_NAME"
xattr -cr "$BUNDLE_DIR" 2>/dev/null || true
find "$BUNDLE_DIR" -name "._*" -delete 2>/dev/null || true
dot_clean "$BUNDLE_DIR" 2>/dev/null || true

echo "📦 macOS Yükleyici Paketi ($APP_NAME.pkg) oluşturuluyor..."
rm -f "$APP_NAME.pkg"

pkgbuild --component "$BUNDLE_DIR" \
         --install-location "/Applications" \
         --identifier "com.avenox.0ne8witch" \
         --version "1.0.1" \
         "$APP_NAME.pkg"

echo ""
echo "🎉 TEBRİKLER! Tüm paketleme işlemleri başarıyla tamamlandı:"
echo "  1. Uygulama Paketi: $BUNDLE_DIR"
echo "  2. macOS Kurulum Paketi: $APP_NAME.pkg"
echo ""
echo "👉 Uygulamayı doğrudan açmak için: open $BUNDLE_DIR"
# Güncelleme modülü için zip paketi oluştur
ZIP_NAME="$APP_NAME.zip"
rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE_DIR" "$ZIP_NAME"
echo "📦 Guncelleme zip'i olusturuldu: $ZIP_NAME"

echo "👉 Yükleyiciyi başlatmak için: open $APP_NAME.pkg"
