#!/usr/bin/env python3
# =====================================================================
#  Kemence Akadémia — FEJLESZTŐI statikus szerver, CACHE NÉLKÜL.
#
#  A sima `python -m http.server` nem küld cache-fejlécet, ezért a böngésző
#  „megtartja" a régi JS/CSS fájlokat (bosszantó, mert a módosítások nem
#  látszanak). Ez a szerver MINDEN válaszra no-store fejlécet tesz, így
#  a böngésző soha nem cache-el — mindig a friss fájlt kapod.
#
#  Futtatás a projekt gyökeréből:   python dev-szerver.py
#  Aztán:  http://localhost:8000/        (főoldal)
#          http://localhost:8000/admin/  (admin)
#
#  (A `web` mappát szolgálja ki. Állítsd le vele az eddigi szervert,
#   hogy ne ütközzön a 8000-es porton.)
# =====================================================================
import http.server
import socketserver
import os

PORT = 8000
GYOKER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
os.chdir(GYOKER)


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


with socketserver.TCPServer(("", PORT), NoCacheHandler) as httpd:
    print(f"Kemence Akadémia dev-szerver — CACHE KIKAPCSOLVA")
    print(f"  főoldal: http://localhost:{PORT}/")
    print(f"  admin:   http://localhost:{PORT}/admin/")
    print("  (Ctrl+C a leállításhoz)")
    httpd.serve_forever()
