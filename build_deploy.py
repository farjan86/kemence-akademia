#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kemence Akadémia — éles telepítési csomag gyártása.

A `web/` mappából legyártja a `deploy_web/` mappát úgy, hogy annak a
TARTALMA 1:1 bemásolható a Hostinger `public_html` gyökerébe, a régi
fájlokat felülírva.

Amit SZÁNDÉKOSAN kihagy:
  1. `js/config.js` — ez a FEJLESZTŐI Supabase projektre mutat. Az éles
     `config.js` már kint van a szerveren; a csomag hozzá sem ér, így a
     feltöltés nem kapcsolhatja az éles oldalt a fejlesztői adatbázishoz.
  2. `.htaccess` — szerveroldali beállítás; az élesben lévőt nem írjuk
     felül a feltöltéssel, azt a szerveren, külön kezeljük.
  3. a `kepek/` mappa nem használt forrásképeit — a listát a
     `deploy-kepek.txt` adja (a programok és előadók fotói a Supabase
     Storage-ból jönnek, nem ebből a mappából).

Mielőtt készre jelenti a csomagot, ELLENŐRZI:
  - nincs-e benne config-szerű fájl (bármilyen `*config*` névre illeszkedő)
    vagy `.htaccess`;
  - nincs-e a szöveges fájlokban fejlesztői/demó nyom: beégetett
    `supabase.co` URL, anon kulcs (JWT), `service_role`, netlify/pages.dev cím;
  - a kód minden hivatkozott képe bekerült-e;
  - megvan-e az `index.html` és az admin felület.

Bármelyik ellenőrzés hibája esetén hibakóddal áll le, és kiírja, hogy a
csomagot nem szabad feltölteni.

Használat:
    python build_deploy.py          # rákérdez a deploy_web ürítésére
    python build_deploy.py --yes    # kérdés nélkül épít
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

GYOKER = Path(__file__).resolve().parent
SRC = GYOKER / "web"
OUT = GYOKER / "deploy_web"
KEPLISTA = GYOKER / "deploy-kepek.txt"

# Fájlnevek, amelyek SOHA nem kerülhetnek a csomagba (bármelyik mappából):
# a config.js a fejlesztői Supabase-re mutat, a .htaccess pedig szerveroldali
# beállítás — mindkettőt a szerveren lévő éles változat képviseli.
KIHAGYOTT_FAJLOK = {"config.js", ".htaccess"}

# Ezek fejlesztői vagy demó rendszerhez kapcsolnák az éles oldalt -> HIBA.
# A beégetett Supabase URL-t és az anon kulcsot a "supabase.co" és az
# "eyJhbGciOi" (a JWT-k kezdete) minta fogja meg, bármelyik projektről
# legyen is szó — így új dev/demó projekt esetén is működik.
TILOS_MINTAK = [
    "supabase.co",
    "eyJhbGciOi",
    "service_role",
    "netlify.app",
    "pages.dev",
]

# Ezek nem kapcsolnak rendszert, csak fejlesztői maradványok -> FIGYELEM.
GYANUS_MINTAK = [
    "localhost",
    "127.0.0.1",
    "resend.dev",
    "onboarding@",
]

# Csak ezekben keresünk mintát. A képekben nem: ott a bináris tartalom
# véletlen egyezéseket adna (pl. a JPEG-ekben előfordul az "eyJ" is).
SZOVEGES_KITERJESZTESEK = {
    ".html", ".htm", ".js", ".css", ".json", ".txt", ".xml", ".svg", ".webmanifest",
}
SZOVEGES_NEVEK = {".htaccess"}

KEP_HIVATKOZAS = re.compile(
    r"kepek/([^\"'()\s>]+\.(?:jpg|jpeg|png|svg|webp|gif|ico))",
    re.IGNORECASE,
)

hibak: list[str] = []
figyelmeztetesek: list[str] = []


def szoveges(p: Path) -> bool:
    return p.suffix.lower() in SZOVEGES_KITERJESZTESEK or p.name.lower() in SZOVEGES_NEVEK


def kepek_listaja() -> list[str]:
    """A deploy-kepek.txt sorai: soronként egy fájlnév, a # kezdetű sorok megjegyzések."""
    nevek = []
    for sor in KEPLISTA.read_text(encoding="utf-8").splitlines():
        sor = sor.strip()
        if sor and not sor.startswith("#"):
            nevek.append(sor)
    return nevek


def masolas(kepnevek: list[str]) -> int:
    """A web/ fájljai a deploy_web/ alá, a kihagyottak nélkül. Visszaadja a képek számát."""
    for mappa, almappak, fajlok in os.walk(SRC):
        mappa = Path(mappa)
        # A kepek/ mappát (az almappáival együtt) kihagyjuk: a képeket a
        # lista alapján másoljuk, lásd lentebb.
        almappak[:] = [d for d in almappak if d != "kepek"]
        for nev in fajlok:
            if nev in KIHAGYOTT_FAJLOK:
                continue
            cel = OUT / mappa.relative_to(SRC) / nev
            cel.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(mappa / nev, cel)

    (OUT / "kepek").mkdir(parents=True, exist_ok=True)
    db = 0
    for nev in kepnevek:
        forras = SRC / "kepek" / nev
        if forras.is_file():
            shutil.copy2(forras, OUT / "kepek" / nev)
            db += 1
        else:
            hibak.append(f"A {KEPLISTA.name} felsorolja, de a web/kepek alatt nincs: {nev}")
    return db


def kephivatkozasok_ellenorzese() -> None:
    """Minden hivatkozott kép bekerült-e a csomagba? Ha nem, élesben törött kép lenne."""
    for p in sorted(OUT.rglob("*")):
        if not (p.is_file() and szoveges(p)):
            continue
        tartalom = p.read_text(encoding="utf-8", errors="replace")
        for talalat in KEP_HIVATKOZAS.findall(tartalom):
            nev = unquote(talalat)
            if not (OUT / "kepek" / nev).is_file():
                hol = p.relative_to(OUT)
                hibak.append(
                    f"{hol}: hivatkozik a kepek/{nev} fájlra, de az nincs a csomagban "
                    f"— vedd fel a {KEPLISTA.name} fájlba."
                )


def nyomok_keresese() -> None:
    """Fejlesztői/demó nyomok a csomag szöveges fájljaiban."""
    for p in sorted(OUT.rglob("*")):
        if not (p.is_file() and szoveges(p)):
            continue
        tartalom = p.read_text(encoding="utf-8", errors="replace")
        kicsi = tartalom.lower()
        hol = p.relative_to(OUT)
        for minta in TILOS_MINTAK:
            if minta.lower() in kicsi:
                hibak.append(f"{hol}: fejlesztői vagy demó adat a csomagban — minta: {minta}")
        for minta in GYANUS_MINTAK:
            if minta.lower() in kicsi:
                figyelmeztetesek.append(f"{hol}: fejlesztői maradvány — minta: {minta}")


def vegellenorzes() -> None:
    """Ami nem mehet ki, és ami biztosan kell."""
    for p in sorted(OUT.rglob("*config*")):
        hibak.append(f"Config-szerű fájl van a csomagban: {p.relative_to(OUT)}")
    for p in sorted(OUT.rglob(".htaccess")):
        hibak.append(f".htaccess van a csomagban: {p.relative_to(OUT)} — szerveroldali, nem mehet fel")

    kell = {
        "index.html": "a publikus főoldal",
        "admin/index.html": "az admin felület",
        "js/app.js": "a publikus oldal logikája",
    }
    for relativ, mire in kell.items():
        if not (OUT / relativ).is_file():
            hibak.append(f"Hiányzik a csomagból: {relativ} — {mire}")


def urites(automata: bool) -> bool:
    if not OUT.exists():
        return True
    print(f"   A {OUT.name} mappa már létezik, és a build a TELJES tartalmát törli.")
    if not automata:
        valasz = input("   Törölhetem? [i/n] ").strip().lower()
        if valasz not in {"i", "igen", "y", "yes"}:
            print("\n   Megszakítva — semmi nem változott.\n")
            return False
    shutil.rmtree(OUT)
    return True


def meret_mb(mappa: Path) -> float:
    return sum(p.stat().st_size for p in mappa.rglob("*") if p.is_file()) / (1024 * 1024)


def main() -> int:
    automata = "--yes" in sys.argv or "-y" in sys.argv

    # A Windows-konzol kódlapja nem feltétlenül ismer minden karaktert —
    # ne a záró kiíráson szálljon el a szkript, miután a csomag már kész.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")

    print()
    print("==========================================================")
    print("   KEMENCE AKADÉMIA — éles telepítési csomag")
    print("==========================================================")
    print()

    if not (SRC / "index.html").is_file():
        print(f"[HIBA] Nem találom a {SRC / 'index.html'} fájlt.")
        print("       A szkript a projekt gyökerébe való, a web mappa mellé.")
        return 1
    if not KEPLISTA.is_file():
        print(f"[HIBA] Nem találom a {KEPLISTA.name} fájlt.")
        print("       Ez a lista mondja meg, mely képek kerülnek a csomagba.")
        return 1

    if not urites(automata):
        return 1

    print("[1/4] Fájlok másolása, config.js és .htaccess nélkül...")
    kepdb = masolas(kepek_listaja())

    print("[2/4] Képhivatkozások ellenőrzése...")
    kephivatkozasok_ellenorzese()

    print("[3/4] Fejlesztői és demó nyomok keresése...")
    nyomok_keresese()

    print("[4/4] A csomag ellenőrzése...")
    vegellenorzes()

    fajldb = sum(1 for p in OUT.rglob("*") if p.is_file())
    print()

    for sor in dict.fromkeys(figyelmeztetesek):
        print(f"   [FIGYELEM] {sor}")
    if figyelmeztetesek:
        print("              Nézd át: megjegyzésben nem baj, de ne kapcsoljon")
        print("              semmit a fejlesztői rendszerhez.")
        print()

    if hibak:
        for sor in dict.fromkeys(hibak):
            print(f"   [HIBA] {sor}")
        print()
        print("==========================================================")
        print("   A BUILD HIBÁVAL ÁLLT LE — a csomagot NE töltsd fel.")
        print("==========================================================")
        print()
        return 1

    print("==========================================================")
    print("   A CSOMAG KÉSZ")
    print("==========================================================")
    print()
    print(f"   Mappa     :  {OUT}")
    print(f"   Fájlok    :  {fajldb} db ({meret_mb(OUT):.1f} MB), ebből kép: {kepdb} db")
    print("   Kihagyva  :  js/config.js, .htaccess (szándékosan)")
    print()
    print("   TELEPÍTÉS a Hostingerre:")
    print("     1. hPanel -> Websites -> kemence-akademia.xyz -> File Manager.")
    print("        Ellenőrizd az útvonalat: .../domains/kemence-akademia.xyz/public_html")
    print(f"     2. Másold be a {OUT.name} mappa TARTALMÁT a public_html gyökerébe,")
    print("        a régi fájlokat felülírva.")
    print("     3. A szerveren lévő js/config.js-hez és .htaccess-hez NE nyúlj —")
    print("        az éles beállítások vannak bennük; a csomagban szándékosan")
    print("        nincs ilyen fájl, a feltöltés nem írja felül őket.")
    print("     4. Ha a .htaccess-t is frissíteni kell, azt külön, kézzel tedd,")
    print("        a szerveren lévő előzetes lementése után.")
    print("     5. hPanel -> Performance (vagy Cache Manager) -> Purge cache,")
    print("        majd a böngészőben Ctrl+F5.")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
