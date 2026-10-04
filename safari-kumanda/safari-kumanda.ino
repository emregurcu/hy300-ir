// HY300 Safari Kumandası
// ESP8266 / ESP32 + IR LED. Kart Wi-Fi'de kumanda sayfasını yayınlar,
// Safari'den basılan tuşlar NEC IR kodu olarak projeksiyona gönderilir.
// Gerekli kütüphane: IRremoteESP8266 (Arduino Library Manager)

#if defined(ESP8266)
  #include <ESP8266WiFi.h>
  #include <ESP8266WebServer.h>
  #include <ESP8266mDNS.h>
  typedef ESP8266WebServer WebServerT;
#elif defined(ESP32)
  #include <WiFi.h>
  #include <WebServer.h>
  #include <ESPmDNS.h>
  typedef WebServer WebServerT;
#else
  #error "Bu proje ESP8266 veya ESP32 kart gerektirir"
#endif

#include <IRremoteESP8266.h>
#include <IRsend.h>
#include "page.h"

// --- Ayarlar -------------------------------------------------------------
// Ev Wi-Fi bilgileri. Boş bırakılırsa ya da bağlanamazsa kart kendi ağını açar.
const char* WIFI_SSID = "";
const char* WIFI_PASS = "";

// Kartın kendi ağı (ev Wi-Fi yoksa): iPhone'dan bu ağa bağlanıp 192.168.4.1 açılır
const char* AP_SSID = "HY300-Kumanda";
const char* AP_PASS = "hy300kumanda";  // en az 8 karakter

const char* HOSTNAME = "hy300";  // http://hy300.local
const uint16_t IR_PIN = 4;       // ESP8266: D2, ESP32: GPIO4
// -------------------------------------------------------------------------

IRsend irsend(IR_PIN);
WebServerT server(80);

static long parseNum(const String& s) {
  return strtol(s.c_str(), nullptr, 0);  // "0x16" veya "22"
}

void handleRoot() {
  server.sendHeader("Cache-Control", "no-cache");
  server.send_P(200, "text/html; charset=utf-8", PAGE_HTML);
}

// GET /send?a=<adres>&c=<komut>  (NEC, Flipper .ir dosyalarındaki değerler)
void handleSend() {
  if (!server.hasArg("a") || !server.hasArg("c")) {
    server.send(400, "text/plain", "a ve c parametreleri gerekli");
    return;
  }
  long a = parseNum(server.arg("a"));
  long c = parseNum(server.arg("c"));
  if (a < 0 || a > 0xFF || c < 0 || c > 0xFF) {
    server.send(400, "text/plain", "gecersiz deger");
    return;
  }
  irsend.sendNEC(irsend.encodeNEC(a, c));
  server.send(200, "text/plain", "ok");
}

void startAP() {
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  Serial.printf("Erisim noktasi: %s  ->  http://%s\n", AP_SSID,
                WiFi.softAPIP().toString().c_str());
}

void setup() {
  Serial.begin(115200);
  irsend.begin();

  bool connected = false;
  if (strlen(WIFI_SSID) > 0) {
    WiFi.mode(WIFI_STA);
#if defined(ESP8266)
    WiFi.hostname(HOSTNAME);
#else
    WiFi.setHostname(HOSTNAME);
#endif
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    Serial.print("Wi-Fi'ye baglaniliyor");
    for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) {
      delay(250);
      Serial.print('.');
    }
    Serial.println();
    connected = WiFi.status() == WL_CONNECTED;
  }

  if (connected) {
    Serial.printf("Baglandi  ->  http://%s  veya  http://%s.local\n",
                  WiFi.localIP().toString().c_str(), HOSTNAME);
  } else {
    startAP();
  }

  if (MDNS.begin(HOSTNAME)) MDNS.addService("http", "tcp", 80);

  server.on("/", handleRoot);
  server.on("/send", handleSend);
  server.onNotFound([]() { server.send(404, "text/plain", "yok"); });
  server.begin();
}

void loop() {
  server.handleClient();
#if defined(ESP8266)
  MDNS.update();
#endif
}
