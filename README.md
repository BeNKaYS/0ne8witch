# 0ne8witch - macOS Menü Çubuğu Anahtar ve Otomasyon Yöneticisi

**0ne8witch**, macOS için geliştirilmiş, tamamen Türkçe ve yerel (native) Swift/SwiftUI menü çubuğu aracıdır. "One Switch" ve "OnlySwitch" uygulamalarının tersine mühendislik ve özellik araştırmaları temel alınarak sıfırdan modern bir mimariyle geliştirilmiştir.

---

## 🌟 Özellikler ve Anahtarlar (13 Adet Native Switch)

### 1. Sistem & Performans
- ☕️ **Uyanık Kal (Keep Awake)**: Mac'inizin uykuya geçmesini engeller. Süresiz veya zamanlayıcı seçenekleri (15 dk, 30 dk, 1 saat, 2 saat) sunar. Arka planda native `/usr/bin/caffeinate` sürecini yönetir.
- 🔋 **Düşük Güç Modu**: Apple Silicon ve Mac pillerinde maksimum tasarruf sağlamak için Düşük Güç Modunu (`pmset -a lowpowermode 1/0`) tek tıkla açar/kapatır.
- 🪟 **Sahne Yöneticisi (Stage Manager)**: macOS pencere yönetim sistemini tek tıkla açar/kapatır.
- 🚢 **Dock'u Otomatik Gizle**: Ekran alanını genişletmek için Dock'un otomatik gizlenme özelliğini açar/kapatır.
- 🔄 **Doğal Kaydırma**: Fare ve trackpad kaydırma yönünü (Klasik / Doğal) tek tıkla değiştirir.

### 2. Ekran & Görünüm
- 🌙 **Karanlık Mod**: Tek tıkla macOS Aydınlık ve Karanlık modları arasında geçiş yapar.
- 🖥️ **Masaüstü Simgelerini Gizle**: Sunum yaparken veya ekran paylaşırken masaüstündeki tüm dosya ve simgeleri anında gizler.
- 👁️ **Gizli Dosyaları Göster**: Finder'daki gizli dosyaları (`.dotfiles`) görünür yapar veya gizler.
- 📄 **Dosya Uzantılarını Göster**: Tüm dosya uzantılarını (`.png`, `.pdf`, `.swift` vb.) Finder'da görünür kılar.
- 🧩 **Masaüstü Araç Takımlarını Gizle**: Masaüstündeki macOS Sonoma+ widget'larını anında saklar veya açar.

### 3. Ses, Medya & Araçlar
- 🎙️ **Mikrofonu Sustur**: Görüşmelerde gizlilik için sistem mikrofonunu sessize alır veya önceki seviyesine döndürür.
- 📁 **Kitaplık Klasörünü Göster**: macOS tarafından gizlenen `~/Library` klasörünü anında Finder'da açığa çıkarır.
- ✨ **Ekran Temizleme Modu**: Ekranı ve klavyeyi temizlemeniz için tam ekran karartma penceresi açar ve kazara tuş basımlarını engeller (`ESC` tuşuyla çıkılır).

---

## ⚡️ Hızlı Eylemler (Quick Actions)
- 🗑️ **Çöp Kutusunu Boşalt**: Finder uyarı pencerelerini ve takılmaları otomatik olarak atlayıp çöpü anında ve sessizce boşaltır, kaç öğe silindiğini ekranda bildirir.
- 📋 **Panoyu Sil**: Kopyalanmış metin ve görselleri panodan tamamen temizler.
- 🔒 **Ekranı Kilitle**: Ekranı hemen kilitler.
- 💫 **Ekran Koruyucu**: Ekran koruyucuyu anında başlatır.
- 🛠️ **Xcode Önbelleğini Temizle**: `~/Library/Developer/Xcode/DerivedData` dizinini temizler.

---

## ⚙️ Kapsamlı Ayarlar Penceresi (Settings)
- 🚀 **Sistem Başlangıcında Aç (Launch at Login)**: Modern macOS 13+ `SMAppService` API'si ile Mac açıldığında otomatik başlatma.
- 🎨 **12 Farklı Menü Çubuğu Simgesi**:
  1. `switch.2` (Çift Anahtar - Varsayılan)
  2. `toggle.power` (Aç/Kapa Güç Anahtarı)
  3. `slider.horizontal.3` (Ayarlar / Kaydırıcı)
  4. `slider.horizontal.2.square.on.square` (Kontrol Merkezi)
  5. `power` (Klasik Güç Düğmesi)
  6. `bolt.fill` (Şimşek / Hızlı Eylem)
  7. `command` (Komut Simgesi ⌘)
  8. `wand.and.stars` (Sihirli Değnek)
  9. `dial.low.fill` (Ayar Kadranı)
  10. `macwindow.on.rectangle` (Pencereler & Ekran)
  11. `sparkles` (Temizlik & Parlaklık)
  12. `gearshape.2.fill` (Sistem Çarkları)
- 🎛️ **Anahtarları Özelleştirme**: Menüde görmek istemediğiniz anahtarları tek tek gizleyebilme.
- 🔔 **Bildirim Tercihleri**: Anahtar durumları değiştiğinde ekran içi toast bildirimlerini yönetebilme.

---

## 📦 Kurulum ve Paketleme

### 1. macOS Kurulum Paketi (.pkg ile Kolay Kurulum):
Doğrudan çift tıklayarak veya Terminal'den açabilirsiniz:
```bash
open 0ne8witch.pkg
```
Bu işlem `0ne8witch.app` uygulamasını doğrudan `/Applications` (Uygulamalar) klasörünüze yükler.

### 2. Uygulamayı Doğrudan Çalıştırma:
```bash
open 0ne8witch.app
```

### 3. Sıfırdan Tekrar Paketleme (Release):
```bash
./build_pkg.sh
```
