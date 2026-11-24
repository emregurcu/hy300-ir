# ParkPlay

Araç için iOS video oynatıcı: IPTV (M3U, Xtream Codes), Jellyfin ve yerel videolar tek uygulamada.
Abonelik, reklam ve izleme kodu yok; parolalar yalnızca cihazın Anahtar Zinciri'nde durur.
ParkPlay içerik sağlamaz, yalnızca sizin eklediğiniz kaynakları oynatır.

## Derleme

Gerekenler: Mac, Xcode 16 veya üstü, iOS 17+ iPhone.

1. `ParkPlay.xcodeproj` dosyasını açın.
2. ParkPlay hedefi → Signing & Capabilities → kendi Team'inizi seçin, gerekirse Bundle Identifier'ı değiştirin.
3. iPhone'u seçip Run'a basın.

Çekirdek kod (M3U ayrıştırıcı, Xtream ve Jellyfin istemcileri) Xcode olmadan da test edilir: `swift test`

## Araç ekranına görüntü

Oynatıcıdaki AirPlay düğmesi görüntüyü AirPlay destekleyen ekrana yollar. iOS 26 ile gelen
"araçta AirPlay video" özelliği, araç üreticisi desteklediyse ve araç park halindeyse CarPlay
ekranında da çalışır. Araç sürerken video Apple tarafından engellenir; bu bilerek aşılmadı.

## Bilinen sınırlar

- Arayüz kodu yalnızca Linux'ta yazıldı; Xcode'da henüz derlenmedi ve gerçek cihazda denenmedi.
- Oynatma AVPlayer ile yapılır: HLS ve MP4 açılır. Ham MPEG-TS, MKV, DTS açılmaz
  (Xtream canlı yayınları HLS olarak istenir, Jellyfin sunucuda dönüştürür). İleride VLCKit eklenebilir.
- Xtream dizileri, Plex, Emby, EPG, altyazı seçimi ve QR ile liste ekleme henüz yok.
- Uygulama simgesi yok.
