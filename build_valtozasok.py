# -*- coding: utf-8 -*-
"""Kemence Akadémia — „Mi újult meg?" tájékoztató az ügyfélnek (.docx).

Rövid, lényegre törő összefoglaló egy fejlesztési körről. NEM szabálykönyv:
a részletes leírás a felhasznaloi-utmutato.docx-ben van.

A Word-formázást (dobozok, táblázat, listák) a build_docx.py-ból veszi át,
hogy a két dokumentum egyformán nézzen ki.

Futtatás a projekt gyökeréből:   python build_valtozasok.py
"""
import os
from docx import Document
from docx.shared import Pt, Cm
from docx.oxml.ns import qn

from build_docx import futasok, doboz, NARANCS, SZURKE

GYOKER = os.path.dirname(os.path.abspath(__file__))
CIM = "Kemence Akadémia — Mi újult meg?"
DATUM = "2026. szeptember"
FAJL = "valtozasok-2026-09.docx"

# ---------------------------------------------------------------------
#  Blokkok:  ("h", cím) · ("p", szöveg) · ("lista", [..]) · ("tipp", szöveg)
# ---------------------------------------------------------------------
TARTALOM = [
("p", "Ez a rövid összefoglaló azt mutatja, mi változott az admin felületen és a foglaló oldalon. "
      "A lépésről lépésre leírás a **felhasználói kézikönyvben** van."),

("h", "Új: Partnerek lista"),
("p", "A Naptár mellett megjelent egy **Partnerek** gomb. Itt egy listában szerepel mindenki, aki valaha foglalt egy programra "
      "vagy ajánlatot kért — **e-mail cím szerint összevonva**, tehát egy sor egy ember. Így egy pillanat alatt látszik, hogy "
      "valaki járt-e már nálatok."),
("lista", [
    "Az **Alkalmak** oszlopban például „2 foglalás · 1 ajánlat”, mellette **Visszatérő** jelvény.",
    "Minden oszlop fölött **kereső**: név, telefon, e-mail, lakcím.",
    "Szűrhetsz **időszakra**, és arra, hogy csak a **megvalósult** alkalmak számítsanak.",
    "A sorra kattintva **lenyílnak az alkalmai**; az azonosítóra kattintva helyben megnyílik a foglalás vagy az ajánlat.",
    "A lista **Excelbe** exportálható, és egy gombbal törölhető az összes szűrés.",
]),

("h", "Számlázási cím a foglalásnál és az ajánlatkérésnél"),
("p", "A vendégnek mostantól meg kell adnia az **irányítószámot**, a **helységet** és a **további címadatot** — enélkül nem tudja "
      "elküldeni az űrlapot. Az adatot az adminban a foglalás **Szerkesztés** ablakában, ajánlatnál a **Részletek** ablakban "
      "láthatod és javíthatod, és az Excel-exportban is benne van."),

("h", "Saját szöveg az űrlapok tetejére"),
("p", "A foglalási űrlapnak eddig is volt egy info-sávja; most az **ajánlatkérő űrlap** is kapott egyet. Mindkettőt a "
      "**Beállítások → Általános** alatt írod át, és azonnal megjelenik a vendégnek. Ha üresen hagyod, a sáv meg sem jelenik. "
      "Ide kerülhet például a számlázásról szóló tájékoztatás."),

("h", "Áttekinthetőbb admin felület"),
("lista", [
    "A **fülsor** a rendszer két ágát követi, saját színnel: nyilvános programok (narancs) és egyedi megrendelések (lila). "
    "A Beállítások külön „Rendszer” csoportba került, a **Naptár** pedig kiemelt, ikonos gomb lett.",
    "A **Beállítások** három alfülre bomlik (Általános · Nyilvános programok · Egyedi megrendelések), és a levélsablonok "
    "szerkesztőmezői nagyobbak lettek.",
    "A csoportos korlátoknál (min. fő / max. foglalás) egy **?** gomb nyit magyarázatot és példákat.",
    "Ha egy programnak lejártak az időpontjai, a főoldalon már nem „Hamarosan”, hanem **Új időpontok egyeztetés alatt** "
    "felirat jelenik meg.",
]),

("h", "Biztonságosabb törlés"),
("lista", [
    "**Egyedi programot** ezentúl csak akkor lehet törölni, ha még nem érkezett rá ajánlatkérés — ugyanaz a szabály, mint a "
    "programoknál. Ha már van előzménye, az **Archiválás** marad.",
    "A törlő ablakok kiírják, ha a törléssel a **partner is kikerül a Partnerek listájából**.",
]),

("tipp", "A Partnerek lista mindig a meglévő foglalásokból és ajánlatokból épül fel. Amit véglegesen törölsz, az onnan is eltűnik — "
         "ezért érdemes inkább **archiválni**, mint törölni."),
]


def gyart():
    doc = Document()
    st = doc.styles["Normal"]
    st.font.name = "Segoe UI"; st.font.size = Pt(10.5)
    st.element.rPr.rFonts.set(qn("w:eastAsia"), "Segoe UI")
    s = doc.styles["Heading 1"]; s.font.name = "Segoe UI"; s.font.size = Pt(14); s.font.color.rgb = NARANCS
    for sec in doc.sections:
        sec.left_margin = sec.right_margin = Cm(2); sec.top_margin = sec.bottom_margin = Cm(1.8)

    c = doc.add_heading(CIM, level=0)
    for r in c.runs: r.font.size = Pt(20); r.font.color.rgb = NARANCS
    p = doc.add_paragraph(DATUM); p.runs[0].font.color.rgb = SZURKE; p.runs[0].font.size = Pt(9.5)

    for b in TARTALOM:
        tip = b[0]
        if tip == "h":
            doc.add_heading(b[1], level=1)
        elif tip == "p":
            par = doc.add_paragraph(); futasok(par, b[1])
        elif tip == "lista":
            for x in b[1]:
                par = doc.add_paragraph()
                pf = par.paragraph_format
                pf.left_indent = Cm(0.9); pf.first_line_indent = Cm(-0.6); pf.space_after = Pt(3)
                par.add_run("•\t"); futasok(par, x)
        elif tip == "tipp":
            doboz(doc, None, ["💡 " + b[1]], "FDF7E3", "D9A441")
    return doc


if __name__ == "__main__":
    gyart().save(os.path.join(GYOKER, FAJL))
    print("Kész:", FAJL)
