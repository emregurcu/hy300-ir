// Otomatik üretildi: python3 make_page.py  (index.html'i düzenleyin)
#pragma once
#include <Arduino.h>
const char PAGE_HTML[] PROGMEM = R"rawliteral(<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="HY300">
<meta name="theme-color" content="#111214">
<title>HY300 Kumanda</title>
<style>
:root{--bg:#111214;--key:#25272c;--key2:#2f3238;--txt:#eceef1;--dim:#8a8f98;--acc:#3d8bfd;--red:#e5484d;--ok:#30a46c}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;height:100%;background:var(--bg);color:var(--txt);font:16px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
body{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;touch-action:manipulation}
main{max-width:380px;margin:0 auto;padding:calc(env(safe-area-inset-top) + 14px) 16px calc(env(safe-area-inset-bottom) + 16px);display:flex;flex-direction:column;gap:18px}
header{display:flex;align-items:center;justify-content:space-between}
h1{font-size:17px;margin:0;font-weight:600}
#st{width:10px;height:10px;border-radius:50%;background:var(--dim);display:inline-block;margin-right:8px;vertical-align:middle;transition:background .15s}
#st.ok{background:var(--ok)}#st.err{background:var(--red)}
.seg{display:flex;background:var(--key);border-radius:10px;padding:3px}
.seg button{border:0;background:none;color:var(--dim);font:600 13px inherit;font-family:inherit;padding:6px 12px;border-radius:8px}
.seg button.on{background:var(--key2);color:var(--txt)}
button.k{border:0;background:var(--key);color:var(--txt);font-family:inherit;font-size:15px;font-weight:500;border-radius:16px;min-height:56px;display:flex;align-items:center;justify-content:center;gap:6px;transition:transform .06s,background .06s}
button.k:active,button.k.pr{background:var(--key2);transform:scale(.95)}
button.k:disabled{opacity:.25}
button.k svg{width:24px;height:24px;stroke:currentColor;fill:none;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}
.top{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px}
.pw{background:var(--red)!important;color:#fff}
.pad{position:relative;width:min(300px,82vw);aspect-ratio:1;margin:0 auto;border-radius:50%;background:var(--key)}
.pad button{position:absolute;border:0;background:none;color:var(--txt);display:flex;align-items:center;justify-content:center}
.pad button svg{width:30px;height:30px;stroke:currentColor;fill:none;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}
.pad .u{top:0;left:30%;width:40%;height:30%}.pad .d{bottom:0;left:30%;width:40%;height:30%}
.pad .l{left:0;top:30%;width:30%;height:40%}.pad .r{right:0;top:30%;width:30%;height:40%}
.pad .u.pr,.pad .d.pr,.pad .l.pr,.pad .r.pr{color:var(--acc)}
.pad .ok{left:30%;top:30%;width:40%;height:40%;border-radius:50%;background:var(--key2);font-size:18px;font-weight:600;transition:transform .06s}
.pad .ok.pr{transform:scale(.94);background:var(--acc)}
.row3{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
.vol{display:grid;grid-template-columns:1fr 1fr 1fr;gap:12px}
small{color:var(--dim);text-align:center;font-size:12px}
</style>
</head>
<body>
<main>
  <header>
    <h1><span id="st"></span>HY300</h1>
    <div class="seg" id="seg">
      <button data-p="C">Pro</button><button data-p="A">A</button><button data-p="B">B</button>
    </div>
  </header>

  <div class="top">
    <button class="k" data-k="Kaynak">Kaynak</button>
    <button class="k" data-k="Fare">Fare</button>
    <button class="k pw" data-k="Guc" aria-label="Güç"><svg viewBox="0 0 24 24"><path d="M12 3v9"/><path d="M6.3 6.3a8 8 0 1 0 11.4 0"/></svg></button>
  </div>

  <div class="pad">
    <button class="u" data-k="Yukari" data-rep aria-label="Yukarı"><svg viewBox="0 0 24 24"><path d="M6 15l6-6 6 6"/></svg></button>
    <button class="l" data-k="Sol" data-rep aria-label="Sol"><svg viewBox="0 0 24 24"><path d="M15 6l-6 6 6 6"/></svg></button>
    <button class="ok" data-k="OK">OK</button>
    <button class="r" data-k="Sag" data-rep aria-label="Sağ"><svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg></button>
    <button class="d" data-k="Asagi" data-rep aria-label="Aşağı"><svg viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg></button>
  </div>

  <div class="row3">
    <button class="k" data-k="Geri" aria-label="Geri"><svg viewBox="0 0 24 24"><path d="M9 14L4 9l5-5"/><path d="M4 9h11a5 5 0 0 1 0 10h-3"/></svg></button>
    <button class="k" data-k="Ana_ekran" aria-label="Ana ekran"><svg viewBox="0 0 24 24"><path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/></svg></button>
    <button class="k" data-k="Secenek" aria-label="Seçenek"><svg viewBox="0 0 24 24"><path d="M4 6h16M4 12h16M4 18h16"/></svg></button>
  </div>

  <div class="vol">
    <button class="k" data-k="Ses_azalt" data-rep aria-label="Ses azalt"><svg viewBox="0 0 24 24"><path d="M11 5L6 9H3v6h3l5 4z"/><path d="M15 12h6"/></svg></button>
    <button class="k" data-k="Sessiz" aria-label="Sessiz"><svg viewBox="0 0 24 24"><path d="M11 5L6 9H3v6h3l5 4z"/><path d="M16 9l5 6M21 9l-5 6"/></svg></button>
    <button class="k" data-k="Ses_artir" data-rep aria-label="Ses artır"><svg viewBox="0 0 24 24"><path d="M11 5L6 9H3v6h3l5 4z"/><path d="M15 12h6M18 9v6"/></svg></button>
  </div>

  <div class="row3">
    <button class="k" data-k="Ayarlar">Ayarlar</button>
    <button class="k" data-k="Tus_98">98</button>
    <button class="k" data-k="Tus_93">93</button>
  </div>

  <small id="info"></small>
</main>
<script>
// NEC kodları: repodaki hy300-kumanda-*.ir dosyalarından
var AB = {Yukari:0x16,Asagi:0x1A,Sol:0x51,Sag:0x50,OK:0x13,Geri:0x19,Ana_ekran:0x11,Ayarlar:0x43,
          Secenek:0x4C,Fare:0x00,Kaynak:0x0F,Ses_azalt:0x10,Ses_artir:0x18,Sessiz:0x41,Guc:0x40};
var P = {
  C: {name:"HY300 Pro (orijinal kumanda)", a:0x00, c:{Yukari:0x03,Asagi:0x02,Sol:0x0E,Sag:0x1A,OK:0x07,
      Geri:0x5C,Ana_ekran:0x48,Secenek:0x13,Fare:0x82,Tus_98:0x98,Tus_93:0x93,Ses_azalt:0x58,
      Ses_artir:0x0B,Sessiz:0x01,Guc:0x14}},
  A: {name:"Kod seti A (adres 1)", a:0x01, c:AB},
  B: {name:"Kod seti B (adres 0)", a:0x00, c:AB}
};
var prof = "C";
try { if (P[localStorage.hy300p]) prof = localStorage.hy300p; } catch (e) {}

var st = document.getElementById("st"), info = document.getElementById("info");
var keys = document.querySelectorAll("[data-k]");

function applyProfile() {
  document.querySelectorAll("#seg button").forEach(function (b) {
    b.classList.toggle("on", b.dataset.p === prof);
  });
  keys.forEach(function (b) { b.disabled = !(b.dataset.k in P[prof].c); });
  info.textContent = P[prof].name;
}
document.querySelectorAll("#seg button").forEach(function (b) {
  b.onclick = function () {
    prof = b.dataset.p;
    try { localStorage.hy300p = prof; } catch (e) {}
    applyProfile();
  };
});

var busy = false;
function send(k) {
  if (busy) return;               // önceki istek bitmeden yenisini yollama
  var p = P[prof], c = p.c[k];
  if (c === undefined) return;
  busy = true;
  fetch("/send?a=" + p.a + "&c=" + c, {cache: "no-store"})
    .then(function (r) { st.className = r.ok ? "ok" : "err"; })
    .catch(function () { st.className = "err"; })
    .then(function () { busy = false; setTimeout(function () { st.className = ""; }, 250); });
}

keys.forEach(function (b) {
  var t1, t2;
  function stop() { clearTimeout(t1); clearInterval(t2); b.classList.remove("pr"); }
  b.addEventListener("pointerdown", function (e) {
    if (b.disabled) return;
    e.preventDefault();
    b.classList.add("pr");
    send(b.dataset.k);
    if (b.hasAttribute("data-rep")) {   // basılı tutunca tekrar
      t1 = setTimeout(function () { t2 = setInterval(function () { send(b.dataset.k); }, 160); }, 400);
    }
  });
  ["pointerup", "pointercancel", "pointerleave"].forEach(function (ev) { b.addEventListener(ev, stop); });
  b.addEventListener("contextmenu", function (e) { e.preventDefault(); });
});

applyProfile();
</script>
</body>
</html>
)rawliteral";
