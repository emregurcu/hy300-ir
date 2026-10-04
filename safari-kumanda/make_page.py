#!/usr/bin/env python3
"""index.html'i firmware'e gömülecek page.h dosyasına çevirir."""
from pathlib import Path

here = Path(__file__).resolve().parent
html = (here / "index.html").read_text(encoding="utf-8")
assert ")rawliteral\"" not in html
(here / "page.h").write_text(
    "// Otomatik üretildi: python3 make_page.py  (index.html'i düzenleyin)\n"
    "#pragma once\n"
    "#include <Arduino.h>\n"
    'const char PAGE_HTML[] PROGMEM = R"rawliteral(' + html + ')rawliteral";\n',
    encoding="utf-8",
)
print("page.h yazildi")
