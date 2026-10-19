# -*- coding: utf-8 -*-
"""
DNS-zona pillanatkep mentese.

Kivulrol kerdezi le a domain nyilvanos rekordjait, es szoveges fajlba menti.
Hasznalat:   python dns-mentes.py kemence-akademia.xyz [tovabbi.domain ...]

Korlat: teljes zonalistat (AXFR) a szolgaltatok szinte sosem engednek, ezert
a szkript egy ismert nev-listat jar vegig. Egy kezi kepernyokeppel egyutt ez
gyakorlatilag teljes kepet ad.
"""
import datetime
import io
import subprocess
import sys

TIPUSOK = ["SOA", "NS", "A", "AAAA", "MX", "TXT", "CAA"]

# Gyakori aldomainek + amiket ez a projekt hasznal (Resend, levelezes, web)
ALNEVEK = [
    "www", "mail", "webmail", "ftp", "cpanel", "smtp", "imap", "pop",
    "autodiscover", "autoconfig", "_dmarc", "send", "rsend",
    "resend._domainkey", "default._domainkey", "google._domainkey",
    "blog", "shop", "api", "demo", "test", "cdn", "m",
]


def lekerdez(nev, tipus, szerver="8.8.8.8"):
    try:
        ki = subprocess.run(
            ["nslookup", "-type=" + tipus, nev, szerver],
            capture_output=True, text=True, timeout=12,
        ).stdout
    except Exception as e:
        return "  (lekerdezes sikertelen: %s)" % e
    sorok = []
    for s in ki.splitlines():
        s = s.rstrip()
        if not s.strip():
            continue
        if s.startswith("Server:") or s.startswith("Address:") and "#53" not in s and sorok == []:
            continue
        if "Non-authoritative" in s or s.startswith("Kiszolg") or s.startswith("Cim:"):
            continue
        sorok.append(s)
    szoveg = "\n".join(sorok)
    if "can't find" in szoveg or "Non-existent" in szoveg or not sorok:
        return None
    # Ha nincs ilyen tipusu rekord, az nslookup a zona SOA-jat irja ki helyette.
    # Ezt ne tevesszuk ossze valodi talalattal.
    if tipus != "SOA" and "primary name server =" in szoveg:
        return None
    # A Windows nslookup a CAA-t nem ismeri: A/AAAA cimeket ad vissza helyette.
    if tipus == "CAA" and ("Address" in szoveg or "Addresses" in szoveg):
        return "  (a Windows nslookup nem tud CAA-t lekerdezni - kezzel ellenorizd)"
    return szoveg


def mentes(domain):
    ma = datetime.date.today().isoformat()
    sorok = [
        "=" * 70,
        "  DNS-ZONA PILLANATKEP",
        "  Domain : %s" % domain,
        "  Keszult: %s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
        "  Forras : nyilvanos DNS-lekerdezes (8.8.8.8)",
        "=" * 70,
        "",
        "--- A DOMAIN SAJAT REKORDJAI ---",
    ]
    for t in TIPUSOK:
        e = lekerdez(domain, t)
        sorok.append("")
        sorok.append("[%s]" % t)
        sorok.append(e if e else "  (nincs ilyen rekord)")

    sorok += ["", "", "--- ALDOMAINEK (ismert nevek vegigprobalva) ---"]
    talalt = 0
    for al in ALNEVEK:
        teljes = al + "." + domain
        for t in ("A", "CNAME", "TXT", "MX"):
            e = lekerdez(teljes, t)
            if e and teljes.lower() in e.lower():
                sorok.append("")
                sorok.append("[%s] %s" % (t, teljes))
                sorok.append(e)
                talalt += 1
    if talalt == 0:
        sorok.append("  (a listazott nevek egyike sem letezik)")

    sorok += [
        "", "", "=" * 70,
        "  MEGJEGYZES: ez NEM teljes zonaexport. Csak a lekerdezett neveket",
        "  tartalmazza. A hitelesen teljes listat a Hostinger hPanel",
        "  Domains -> DNS / Nameservers kepernyoje mutatja.",
        "=" * 70,
    ]

    fajl = "dns-mentes-%s-%s.txt" % (domain.replace(".", "-"), ma)
    io.open(fajl, "w", encoding="utf-8").write("\n".join(sorok))
    print("mentve:", fajl, "(%d aldomain-talalat)" % talalt)
    return fajl


if __name__ == "__main__":
    for d in (sys.argv[1:] or ["kemence-akademia.xyz"]):
        mentes(d)
