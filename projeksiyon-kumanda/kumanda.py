#!/usr/bin/env python3
"""HY300 Safari kumandası.

Bilgisayarda çalışır, projeksiyona ADB (Wi-Fi) ile bağlanır ve telefondaki
Safari'ye kumanda sayfası sunar. Projeksiyon yeniden başlarsa otomatik olarak
tekrar bağlanır.

Kullanım:
    python3 kumanda.py                  # projeksiyonu ağda kendisi bulur
    python3 kumanda.py 192.168.31.50    # projeksiyonun IP adresiyle
    python3 kumanda.py --port 8080      # farklı port
Gerekenler: Python 3.8+, adb (Android platform-tools)
"""
import argparse
import concurrent.futures
import json
import queue
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONFIG = HERE / "ayar.json"
ADB_PORT = 5555

KEYS = {
    "yukari": 19, "asagi": 20, "sol": 21, "sag": 22, "ok": 23,
    "geri": 4, "ana_ekran": 3, "menu": 82,
    "ses_azalt": 25, "ses_artir": 24, "sessiz": 164,
    "sil": 67, "enter": 66, "oynat_dur": 85, "guc": 26,
}
APPS = {
    "stremio": ["com.stremio.one", "stremio"],
    "youtube": ["com.google.android.youtube.tv", "com.liskovsoft.smarttubetv",
                "com.google.android.youtube", "youtube"],
}
TR = str.maketrans("çğıöşüÇĞİÖŞÜâîû", "cgiosuCGIOSUaiu")

ADB = shutil.which("adb") or "adb"


def adb(*args, timeout=10):
    try:
        r = subprocess.run([ADB, *args], capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def port_open(ip):
    try:
        with socket.create_connection((ip, ADB_PORT), timeout=0.4):
            return ip
    except OSError:
        return None


def find_projector():
    base = local_ip().rsplit(".", 1)[0]
    print(f"Projeksiyon aranıyor ({base}.0/24, port {ADB_PORT})...")
    with concurrent.futures.ThreadPoolExecutor(64) as ex:
        found = [ip for ip in ex.map(port_open, (f"{base}.{i}" for i in range(1, 255))) if ip]
    return found


class Projector:
    def __init__(self, ip):
        self.serial = f"{ip}:{ADB_PORT}"
        self.ip = ip
        self.connected = False
        self.unauthorized = False
        self.size = (1920, 1080)
        self.pkgs = {}
        self.shell = None
        self.q = queue.Queue()
        threading.Thread(target=self._watch, daemon=True).start()
        threading.Thread(target=self._work, daemon=True).start()

    # --- bağlantı ---------------------------------------------------------
    def _watch(self):
        while True:
            state = adb("-s", self.serial, "get-state", timeout=5)
            if state != "device":
                if self.connected:
                    print("Projeksiyon bağlantısı koptu, yeniden deneniyor...")
                self.connected = False
                self._close_shell()
                out = adb("connect", self.serial, timeout=8)
                self.unauthorized = "unauthorized" in out or "authenticate" in out
                state = adb("-s", self.serial, "get-state", timeout=5)
            if state == "device" and not self.connected:
                self._on_connect()
            time.sleep(3)

    def _on_connect(self):
        m = re.findall(r"(\d+)x(\d+)", adb("-s", self.serial, "shell", "wm", "size"))
        if m:
            w, h = map(int, m[-1])  # varsa "Override size" geçerli
            self.size = (max(w, h), min(w, h))
        installed = adb("-s", self.serial, "shell", "pm", "list", "packages", timeout=20)
        installed = [l.split(":", 1)[1] for l in installed.splitlines() if ":" in l]
        for app, prefs in APPS.items():
            self.pkgs[app] = next((p for pref in prefs for p in installed
                                   if p == pref or (pref in p and "." not in pref)
                                   or p.startswith(pref + ".")), None)
        self.connected = True
        self.unauthorized = False
        print(f"Projeksiyona bağlandı: {self.serial}  ekran {self.size[0]}x{self.size[1]}  "
              f"uygulamalar {self.pkgs}")

    def _close_shell(self):
        if self.shell:
            try:
                self.shell.kill()
            except OSError:
                pass
            self.shell = None

    def _run(self, cmd):
        # Tek bir kalıcı "adb shell" üzerinden komut gönderir (her seferinde adb başlatmaktan hızlı)
        for _ in range(2):
            if not self.shell or self.shell.poll() is not None:
                self.shell = subprocess.Popen([ADB, "-s", self.serial, "shell"],
                                              stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                              stderr=subprocess.DEVNULL, text=True)
            try:
                self.shell.stdin.write(cmd + "\n")
                self.shell.stdin.flush()
                return
            except (BrokenPipeError, OSError):
                self._close_shell()

    def _work(self):
        while True:
            item = self.q.get()
            # Art arda gelen tuşları tek "input keyevent" komutunda birleştir
            if item[0] == "key":
                codes = [item[1]]
                while len(codes) < 8:
                    try:
                        nxt = self.q.get_nowait()
                    except queue.Empty:
                        break
                    if nxt[0] != "key":
                        self._run("input keyevent " + " ".join(map(str, codes)))
                        codes = []
                        item = nxt
                        break
                    codes.append(nxt[1])
                if codes:
                    self._run("input keyevent " + " ".join(map(str, codes)))
                    continue
            if item[0] == "raw":
                self._run(item[1])

    # --- komutlar -----------------------------------------------------------
    def key(self, name):
        if name not in KEYS:
            return False
        if self.q.qsize() < 4:  # basılı tutmada kuyruk şişmesin
            self.q.put(("key", KEYS[name]))
        return True

    def _xy(self, x, y):
        x = min(max(float(x), 0.0), 1.0)
        y = min(max(float(y), 0.0), 1.0)
        return round(x * (self.size[0] - 1)), round(y * (self.size[1] - 1))

    def tap(self, x, y):
        self.q.put(("raw", "input tap %d %d" % self._xy(x, y)))
        return True

    def swipe(self, x1, y1, x2, y2, ms):
        ms = int(min(max(float(ms), 80), 1500))
        self.q.put(("raw", "input swipe %d %d %d %d %d" % (*self._xy(x1, y1), *self._xy(x2, y2), ms)))
        return True

    def text(self, t):
        t = str(t).translate(TR)
        t = "".join(c for c in t if 32 <= ord(c) < 127)[:500]
        if not t:
            return False
        t = t.replace(" ", "%s").replace("'", "'\\''")
        self.q.put(("raw", f"input text '{t}'"))
        return True

    def app(self, name):
        if name == "ayarlar":
            self.q.put(("raw", "am start -a android.settings.SETTINGS >/dev/null 2>&1"))
            return True
        pkg = self.pkgs.get(name)
        if not pkg:
            return False
        self.q.put(("raw",
                    f"monkey -p {pkg} -c android.intent.category.LEANBACK_LAUNCHER 1 >/dev/null 2>&1"
                    f" || monkey -p {pkg} -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1"))
        return True

    def status(self):
        return {"connected": self.connected, "unauthorized": self.unauthorized,
                "ip": self.ip, "size": self.size,
                "apps": {k: bool(v) for k, v in self.pkgs.items()}}


PROJ = None
PAGE = (HERE / "index.html").read_bytes()


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._send(200, PAGE, "text/html; charset=utf-8")
        elif self.path == "/api/status":
            self._send(200, PROJ.status())
        else:
            self._send(404, {"error": "yok"})

    def do_POST(self):
        try:
            n = int(self.headers.get("Content-Length") or 0)
            d = json.loads(self.rfile.read(n) or b"{}")
            route = self.path
            if route == "/api/key":
                ok = PROJ.key(d["k"])
            elif route == "/api/tap":
                ok = PROJ.tap(d["x"], d["y"])
            elif route == "/api/swipe":
                ok = PROJ.swipe(d["x1"], d["y1"], d["x2"], d["y2"], d.get("ms", 300))
            elif route == "/api/text":
                ok = PROJ.text(d["t"])
            elif route == "/api/app":
                ok = PROJ.app(d["a"])
            else:
                return self._send(404, {"error": "yok"})
        except (KeyError, ValueError, TypeError):
            return self._send(400, {"error": "geçersiz istek"})
        self._send(200 if ok else 400, {"ok": ok, "connected": PROJ.connected})

    def log_message(self, *a):
        pass


def main():
    sys.stdout.reconfigure(line_buffering=True)
    global PROJ
    ap = argparse.ArgumentParser(description="HY300 Safari kumandası")
    ap.add_argument("ip", nargs="?", help="projeksiyonun IP adresi")
    ap.add_argument("--port", type=int, default=80, help="web sunucu portu (varsayılan 80)")
    args = ap.parse_args()

    if not shutil.which(ADB):
        sys.exit("adb bulunamadı. Android platform-tools kurun (README'ye bakın).")

    ip = args.ip
    if not ip:
        try:
            ip = json.loads(CONFIG.read_text())["ip"]
            print(f"Kayıtlı projeksiyon: {ip}")
        except (OSError, ValueError, KeyError):
            found = find_projector()
            if not found:
                sys.exit("Ağda ADB açık cihaz bulunamadı. Projeksiyonda kablosuz hata ayıklamayı "
                         "açın veya IP adresini verin: python3 kumanda.py <ip>")
            if len(found) > 1:
                print("Birden fazla cihaz bulundu:", ", ".join(found), "- ilki kullanılıyor.")
            ip = found[0]
    try:
        CONFIG.write_text(json.dumps({"ip": ip}))
    except OSError:
        pass

    PROJ = Projector(ip)
    port = args.port
    try:
        srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    except (PermissionError, OSError):
        port = 8080
        srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    url = f"http://{local_ip()}" + ("" if port == 80 else f":{port}")
    print(f"\nKumanda hazır. Telefonda Safari'den açın:  {url}\n(Kapatmak için Ctrl+C)\n")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
