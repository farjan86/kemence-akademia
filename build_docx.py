# -*- coding: utf-8 -*-
"""Kemence Akadémia — Admin kézikönyv.

EGY forrásból (a lenti TARTALOM) készül a két változat, így mindig egyformák:
    felhasznaloi-utmutato.html   és   felhasznaloi-utmutato.docx

Futtatás a projekt gyökeréből:   python build_docx.py
(Kell hozzá:  python -m pip install python-docx)

A szövegben:  **félkövér**   és   `kód`   jelölés használható.
"""
import os, re, html
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

GYOKER = os.path.dirname(os.path.abspath(__file__))
CIM = "Kemence Akadémia — Admin kézikönyv"
ALCIM = "Rövid, gyakorlati útmutató: mit hol találsz, és mit csinálj egy-egy helyzetben."
FRISSITVE = "Frissítve: 2026-09-18"

# ---------------------------------------------------------------------
#  TARTALOM — blokkok:
#    ("h1", cím)  fejezet          ("h2", cím)  helyzet
#    ("p", szöveg)                 ("lepesek", [..])  számozott lépések
#    ("lista", [..])               ("tipp", szöveg)   💡 Miért / jó tudni
#    ("figyelem", szöveg)          ("tabla", [fejléc], [[sor], ..])
#    ("kep", leírás)  képernyőkép helye
# ---------------------------------------------------------------------
TARTALOM = [
("bevezeto", [
    "**Nyilvános oldal** — a vendégek itt foglalnak időpontra, vagy kérnek egyedi ajánlatot.",
    "**Admin felület** (`/admin/`) — itt kezeled mindezt. Belépés a kapott e-mail címmel és jelszóval; regisztráció nincs.",
]),

# =====================================================================
("h1", "1. Eligazodás az admin felületen"),
("p", "A fülsor két üzletágra oszlik, mindkettőnek saját színe van:"),
("tabla", ["Csoport", "Fülek", "Mire való"], [
    ["**Nyilvános programok** (narancs)", "Foglalások, Programok", "Meghirdetett időpontok, amikre a vendég azonnal foglal."],
    ["**Egyedi megrendelések** (lila)", "Ajánlatok, Egyedi programok", "Időpont nélküli ötletek (pl. leánybúcsú, csapatépítő), amikre a vendég ajánlatot kér."],
    ["jobb oldalt", "Naptár, ⚙ Beállítások", "A Naptár mindkét ágat mutatja. A Beállításokban a címek, azonosítók és levélsablonok vannak."],
]),
("tipp", "Mindkét ágban ugyanaz a logika: a **Programok** / **Egyedi programok** fülön azt állítod be, **mit kínálsz**; a **Foglalások** / **Ajánlatok** fülön azt intézed, **ami beérkezett**."),
("kep", "az admin fülsora"),

# =====================================================================
("h1", "2. Programok és időpontok"),

("h2", "Új programot hirdetnék meg"),
("lepesek", [
    "**Programok** fül → **+ Új program**.",
    "Töltsd ki: **cím**, **rövid leírás** (ez látszik a kártyán), és ha kell: részletes leírás, előadó, várható időtartam, fotó.",
    "Állapot: **Aktív**, ha már foglalható. **Hamarosan**, ha csak előre beharangoznád (időpont nélkül, nem foglalható).",
    "**+ Időpont hozzáadása** — minden alkalomhoz: dátum és idő, ár/fő, kedvezményes ár (nem kötelező), max. létszám.",
    "**Mentés**. A jövőbeli, aktív időpontok azonnal foglalhatók a főoldalon.",
]),
("tipp", "Egy program = egy kártya a főoldalon, akárhány időponttal. Ha ugyanazt a workshopot többször tartod, ne csinálj új programot, csak adj hozzá időpontot."),

("h2", "Módosítanék egy programot vagy időpontot"),
("lepesek", [
    "A programnál **Szerkesztés**.",
    "Írd át, amit kell (szöveg, fotó, ár, létszám), új alkalomhoz **+ Időpont hozzáadása**.",
    "**Mentés**.",
]),
("tipp", "A max. létszámot nem viheted a már lefoglalt létszám alá — a rendszer szól, és visszaállítja."),

("h2", "Csak csoportoknak szánt (zártkörű) alkalmat hirdetnék"),
("p", "Az időpont sorában két nem kötelező mező van:"),
("lista", [
    "**Min. fő/foglalás** — egy foglalás legalább ennyi fős lehet (pl. 8).",
    "**Max. foglalás** — összesen ennyi foglalás (csapat) jöhet (pl. 1 = egy csapat viszi az egészet).",
]),
("p", "A kettő független, bármelyik megadható egyedül is. Az időpont magától lezár, ha elérte a max. foglalások számát, vagy ha a maradék hely kevesebb a minimumnál."),
("tipp", "Zártkörű alkalomhoz add meg **mindkettőt** (pl. Max. 1 foglalás + Min. 10 fő) — különben egy 2 fős foglalás is lezárja az egész alkalmat. Példák: a mezők alatti **?** gomb."),

("h2", "Elmarad egy alkalom"),
("lepesek", [
    "A programnál **Szerkesztés** → az időpont állapota: **Elmarad** → **Mentés**.",
    "Ha van rá foglalás, a rendszer megkérdezi: lemondja őket **levél nélkül**, vagy **„sajnos elmarad” levéllel**.",
]),
("tipp", "Foglalással rendelkező időpontot ne törölj — az „Elmarad” megőrzi a nyomát és értesíti a vendégeket. Törölni (✕) a foglalás nélküli időpontot lehet."),

("h2", "Egy időre leállítanám a foglalást"),
("lista", [
    "**Egy programra:** a programnál **Foglalás felfüggesztése**. A főoldalon látszik, de nem foglalható. Visszakapcsolás: **Foglalás engedélyezése**.",
    "**Mindenre:** a Programok fül tetején **Minden foglalás felfüggesztése**. A feloldás mindent visszaenged.",
]),
("tipp", "Akkor hasznos, ha még nem biztos, hogy elindul egy program, vagy épp átírod az adatait. A meglévő foglalások megmaradnak."),

("h2", "Lement a program — eltenném vagy törölném"),
("lista", [
    "**Archiválás** — lekerül a főoldalról, de az adatok és a foglalások megmaradnak (**Archivált programok** alfül). Bármikor visszaállítható. **Általában ezt válaszd.**",
    "**Törlés** — végleg eltűnik minden időpontjával. Csak foglalás nélküli programnál jelenik meg.",
]),
("p", "Hogy milyen sorrendben látszanak a főoldalon: a programlistában a **⠿** fogantyúnál húzd át őket."),

# =====================================================================
("h1", "3. Foglalások"),

("h2", "Egy foglalás útja"),
("tabla", ["Státusz", "Mit jelent", "Foglal helyet?"], [
    ["**Jóváhagyásra vár**", "Új foglalás, még nem döntöttél.", "Igen"],
    ["**Jóváhagyott**", "Elfogadtad, a hely biztos.", "Igen"],
    ["**Elutasított**", "Nem fogadtad el.", "Nem — a hely felszabadul"],
    ["**Lemondott**", "A vendég lemondta.", "Nem — a hely felszabadul"],
]),
("p", "A **Foglalások** fülön minden státusz külön alfül (zárójelben a darabszám); az **Összes foglalás** mindent mutat. Szűrhetsz időpontra, névre, és arra, hogy jövőbeli / mai / múltbéli."),

("h2", "Új foglalás érkezett — mit csináljak?"),
("p", "A vendég azonnal kap egy automatikus visszaigazolást („megkaptuk”), te pedig értesítőt a csapat e-mail címére."),
("lepesek", [
    "**Foglalások** → **Jóváhagyásra vár**.",
    "Nézd meg a foglalást (a 📝 jel = van megjegyzése). Ha rendben van (pl. megjött az utalás): **Jóváhagyás**.",
    "Utána a sorban **✉ Levél** → elküldöd a jóváhagyó levelet. A szöveg küldés előtt átírható.",
    "Ha nem tudod fogadni: **Elutasítás**, majd **✉ Levél** az elutasítóval.",
]),
("tipp", "**Miért két lépés?** A státuszváltás magától nem küld levelet. Így előbb dönthetsz, és a levelet személyre szabhatod."),
("kep", "a Foglalások lista egy sorral és a gombokkal"),

("h2", "A vendég lemondta"),
("lepesek", [
    "A foglalásnál **Vendég lemondta**.",
    "Ha kell, **✉ Levél** a lemondás visszaigazolásával.",
]),
("tipp", "A hely azonnal felszabadul, és újra foglalható."),

("h2", "Más létszámmal jönnének, vagy másik időpontra mennének"),
("lepesek", [
    "A foglalásnál **Szerkesztés**.",
    "Átírhatod a nevet, elérhetőségeket, létszámot, megjegyzést, és áthelyezheted **ugyanannak a programnak** egy másik időpontjára.",
    "**Mentés**.",
]),
("tipp", "Áthelyezni csak **azonos árú** időpontra lehet — eltérő árnál a vendégnek újra kell foglalnia. A férőhelyet a rendszer itt is betartja; a csoportos minimum alá viszont engedi (csak rákérdez)."),

("h2", "Tévedésből hagytam jóvá"),
("p", "A foglalásnál **Jóváhagyás visszavonása** — visszakerül „Jóváhagyásra vár” állapotba."),

("h2", "Takarítás: régi, lezárt foglalások"),
("p", "Elutasított vagy lemondott foglalásnál megjelenik a **🗑 Törlés**, ami véglegesen eltávolítja. Élő (váró vagy jóváhagyott) foglalást nem lehet törölni."),

# =====================================================================
("h1", "4. Egyedi programok és ajánlatok"),
("p", "Az egyedi ág **időpont és ár nélküli ötleteket** kínál (pl. leánybúcsú, céges csapatépítő). A vendég ezekre **ajánlatot kér**; az árat és az időpontot e-mailben egyeztetitek, a rendszer pedig nyilvántartja, hol tart az ügy."),

("h2", "Új ötletet tennék ki a főoldalra"),
("lepesek", [
    "**Egyedi programok** fül → **+ Új egyedi program**.",
    "Cím, rövid leírás (a kártyára), részletes leírás (nem kötelező), fotó.",
    "**Mentés**. A kártyán a vendég a **„Kérjen egyedi ajánlatot”** gombot látja.",
]),
("tipp", "Ha egy ötletet már nem kínálsz: **Archiválás** — a beérkezett kérések megmaradnak. Sorrend: a **⠿** fogantyúnál húzd."),

("h2", "Ajánlatkérés érkezett — a teljes menet"),
("p", "A vendég automatikus visszaigazolást kap, te értesítőt a csapat címére. A kérés **Ajánlatra vár** állapotban jelenik meg."),
("lepesek", [
    "**Ajánlatok** → **Részletek**: mit kér (létszám, kívánt időpont, üzenet). Ide írhatsz **belső jegyzetet** is — a vendég soha nem látja.",
    "Állítsd össze az ajánlatot, és küldd el a vendégnek **a saját leveleződből**.",
    "Jelöld a rendszerben: **Ajánlat kiküldve**. Így látszik, hogy a válaszára vársz.",
    "Ha elfogadta: **Elfogad** → a **végleges** időpont, létszám, **összár** (a teljes rendezvényre, nem fejenként) és az ajánlat szövege (lehet „Ajánlat a csatolmány szerint”). Fájlt is csatolhatsz.",
    "Végül **✉ Levél** → megerősítő levél a végleges adatokkal (a csatolmánnyal együtt).",
]),
("tipp", "**Miért érdemes elfogadni a rendszerben is?** Az elfogadott ajánlat **lilával a Naptárba** kerül, így egy helyen látod a foglalásokkal."),
("kep", "az Ajánlatok lista és az Elfogad ablak"),

("h2", "Változott a megbeszélt időpont vagy ár"),
("lepesek", [
    "Az ajánlatnál **Részletek** → **Végleges adatok módosítása / megtekintése**.",
    "Írd át, **Mentés**. Ha kell, küldj új megerősítést (**✉ Levél**).",
]),

("h2", "Nem lesz belőle rendezvény"),
("lista", [
    "**Elutasítás** — ha te nem vállalod.",
    "**Lemondás** — ha a vendég lépett vissza (elfogadott ajánlatnál is).",
]),
("p", "Mindkettő után küldhetsz levelet (**✉ Levél**). A lezárt ajánlatok a **🗑 Törlés** gombbal takaríthatók."),

# =====================================================================
("h1", "5. Közös eszközök"),

("h2", "Ki jön holnap? — Naptár és résztvevőlista"),
("lepesek", [
    "**Naptár** fül → lépj a kívánt időszakra.",
    "Kattints az alkalomra: látod a foglalókat elérhetőséggel és létszámmal.",
    "**📄 Jelentés (PDF)** — nyomtatható résztvevőlista a helyszínre.",
]),
("p", "A színek a telítettséget jelzik (zöld = van hely, narancs = majdnem tele, piros = betelt); a **lila** az elfogadott egyedi ajánlat. Éves lista vagy havi rács nézet: a Beállításokban választod."),

("h2", "Kiexportálnám Excelbe"),
("p", "A **Foglalások** és az **Ajánlatok** fülön a **📊 Excel** gomb az éppen látott listát tölti le (az aktív alfül és a szűrők szerint)."),

("h2", "Milyen levelek mennek ki?"),
("tabla", ["Levél", "Mikor", "Hogyan"], [
    ["Visszaigazolás a vendégnek + értesítő nektek", "foglaláskor és ajánlatkéréskor", "automatikus"],
    ["Jóváhagyás / elutasítás / lemondás (foglalás)", "státuszváltás után", "te küldöd: **✉ Levél**"],
    ["Megerősítés / elutasítás / lemondás (ajánlat)", "státuszváltás után", "te küldöd: **✉ Levél**"],
    ["Emlékeztető", "a program előtti napon", "automatikus"],
    ["„Sajnos elmarad”", "időpont elmaradásakor", "választható, mindenkinek egyszerre"],
    ["Maga az ajánlat", "egyeztetéskor", "a saját leveleződből, a rendszeren kívül"],
]),
("p", "A vendégek válasza a **csapat e-mail címre** érkezik. A soron a „✉ N kiment levél” linken látod, mi ment már ki."),

("h2", "Beállítások"),
("lista", [
    "**Csapat e-mail cím** — ide jönnek az értesítők, és erre válaszolnak a vendégek. Valódi, olvasott postafiók legyen.",
    "**Foglalási info-sáv** — rövid szöveg a foglalási űrlapon (pl. „előre utalás szükséges”).",
    "**Naptár megjelenítése** — éves lista vagy havi rács.",
    "**Azonosító-formátum** — külön a foglalásoknak (pl. F-100) és az ajánlatoknak (pl. A-100).",
    "**E-mail sablonok** — külön a foglalási és az ajánlati levelekhez. A kapcsos zárójeles mezők (pl. `{nev}`, `{program}`) küldéskor kitöltődnek, és a ✉ Levél ablakban még átírhatod a szöveget.",
]),

("h2", "Főoldali képek cseréje"),
("p", "A program-fotókat az adminban, a program szerkesztőjében cseréled. A főoldal fix képei (felső diavetítés, csapatkép, logó, workshop-képek) a `web/kepek/` mappában vannak: az új képet **ugyanazon a néven** mentsd, majd tedd ki újra az oldalt. Ideális méret: 1400–2000 px széles, 200–400 KB-os JPG."),

("osszegzes", [
    "**Foglalás:** értesítő e-mail → **Jóváhagyás** + **✉ Levél** → előző nap automatikus emlékeztető → Naptár → **Jelentés (PDF)** a helyszínre.",
    "**Ajánlat:** értesítő e-mail → **Részletek** → ajánlat a saját leveleződből → **Ajánlat kiküldve** → **Elfogad** → **✉ Levél** → lilával a Naptárban.",
]),
]


# =====================================================================
#  Inline jelölés:  **félkövér**,  `kód`
# =====================================================================
JELOLES = re.compile(r"(\*\*.+?\*\*|`.+?`)")

def darabol(szoveg):
    """[(szöveg, 'b'|'code'|None), ...]"""
    ki = []
    for d in JELOLES.split(szoveg):
        if not d: continue
        if d.startswith("**") and d.endswith("**"): ki.append((d[2:-2], "b"))
        elif d.startswith("`") and d.endswith("`"): ki.append((d[1:-1], "code"))
        else: ki.append((d, None))
    return ki

def inline_html(szoveg):
    out = []
    for t, s in darabol(szoveg):
        e = html.escape(t, quote=False)
        out.append(f"<b>{e}</b>" if s == "b" else f"<code>{e}</code>" if s == "code" else e)
    return "".join(out)


# =====================================================================
#  HTML
# =====================================================================
CSS = """
  :root{--bg:#faf6f0; --card:#fff; --ink:#241a12; --muted:#7a6a58; --line:#e7ddd0;
    --accent:#e4571b; --accent-2:#b8430f; --egyedi:#8a5cc7; --code:#f3ece2}
  *{box-sizing:border-box}
  body{margin:0; background:var(--bg); color:var(--ink);
    font-family:"Segoe UI",system-ui,-apple-system,sans-serif; line-height:1.6; font-size:16px}
  .wrap{max-width:860px; margin:0 auto; padding:32px 22px 80px}
  header h1{font-size:30px; margin:0 0 6px}
  header p{color:var(--muted); margin:0 0 4px}
  .frissitve{font-size:13px}
  h1.fejezet{font-size:24px; margin:44px 0 10px; padding-bottom:6px; border-bottom:2px solid var(--line)}
  h2{font-size:18px; margin:26px 0 6px; color:var(--accent-2)}
  p{margin:8px 0}
  code{background:var(--code); padding:1px 6px; border-radius:5px; font-family:"Cascadia Code",Consolas,monospace; font-size:14px}
  ol,ul{margin:8px 0; padding-left:24px} li{margin:4px 0}
  table{border-collapse:collapse; width:100%; margin:12px 0; background:var(--card)}
  th,td{border:1px solid var(--line); padding:7px 11px; text-align:left; vertical-align:top}
  th{background:#f6efe6; font-size:14px}
  .doboz{border-left:4px solid var(--accent); background:#fff4ee; padding:10px 15px; border-radius:8px; margin:12px 0}
  .doboz.tipp{border-color:#d9a441; background:#fdf7e3}
  .doboz.osszeg{border-color:var(--egyedi); background:#f5effb}
  .doboz ul{margin:4px 0}
  .kep{border:2px dashed #c9b79f; background:#faf3e9; color:#8a7458; border-radius:10px;
    padding:16px; margin:12px 0; text-align:center; font-size:14px}
  .tartalom{margin:18px 0}
  .tartalom a{display:block; padding:2px 0; text-decoration:none; color:var(--accent-2)}
  @media print{ body{background:#fff} .kep{display:none} }
"""

def html_gyart():
    t = []
    t.append(f'<header><h1>🔥 {html.escape(CIM)}</h1><p>{html.escape(ALCIM)}</p>'
             f'<p class="frissitve">{FRISSITVE} · A 📷 jelölés a később beillesztendő képernyőképek helye.</p></header>')
    for i, b in enumerate(TARTALOM):
        tip = b[0]
        if tip == "bevezeto":
            t.append('<div class="doboz"><b>A rendszer két része</b><ul>'
                     + "".join(f"<li>{inline_html(x)}</li>" for x in b[1]) + "</ul></div>")
            t.append('<div class="tartalom"><b>Tartalom</b>'
                     + "".join(f'<a href="#f{j}">{html.escape(x[1])}</a>'
                               for j, x in enumerate(TARTALOM) if x[0] == "h1") + "</div>")
        elif tip == "h1":        t.append(f'<h1 class="fejezet" id="f{i}">{html.escape(b[1])}</h1>')
        elif tip == "h2":        t.append(f"<h2>{html.escape(b[1])}</h2>")
        elif tip == "p":         t.append(f"<p>{inline_html(b[1])}</p>")
        elif tip == "lepesek":   t.append("<ol>" + "".join(f"<li>{inline_html(x)}</li>" for x in b[1]) + "</ol>")
        elif tip == "lista":     t.append("<ul>" + "".join(f"<li>{inline_html(x)}</li>" for x in b[1]) + "</ul>")
        elif tip == "tipp":      t.append(f'<div class="doboz tipp">💡 {inline_html(b[1])}</div>')
        elif tip == "figyelem":  t.append(f'<div class="doboz">⚠️ {inline_html(b[1])}</div>')
        elif tip == "kep":       t.append(f'<div class="kep">📷 <b>Képernyőkép:</b> {html.escape(b[1])}</div>')
        elif tip == "tabla":
            fej, sorok = b[1], b[2]
            t.append("<table><tr>" + "".join(f"<th>{html.escape(h)}</th>" for h in fej) + "</tr>"
                     + "".join("<tr>" + "".join(f"<td>{inline_html(c)}</td>" for c in s) + "</tr>" for s in sorok)
                     + "</table>")
        elif tip == "osszegzes":
            t.append('<div class="doboz osszeg"><b>Röviden, a napi rutin</b><ul>'
                     + "".join(f"<li>{inline_html(x)}</li>" for x in b[1]) + "</ul></div>")
    return ("<!doctype html>\n<html lang=\"hu\">\n<head>\n<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
            f"<title>{html.escape(CIM)}</title>\n"
            "<!-- GENERÁLT FÁJL — ne kézzel szerkeszd! Forrás: build_docx.py (TARTALOM) -->\n"
            f"<style>{CSS}</style>\n</head>\n<body>\n<div class=\"wrap\">\n"
            + "\n".join(t) + "\n</div>\n</body>\n</html>\n")


# =====================================================================
#  DOCX
# =====================================================================
NARANCS = RGBColor(0xB8, 0x43, 0x0F)
SZURKE  = RGBColor(0x7A, 0x6A, 0x58)

def futasok(par, szoveg, alap_bold=False):
    for t, s in darabol(szoveg):
        r = par.add_run(t)
        r.bold = alap_bold or s == "b"
        if s == "code":
            r.font.name = "Consolas"; r.font.size = Pt(10)

def arnyekol(par, szin, keret):
    """Bekezdés háttérszín + bal oldali színes csík (a HTML-es dobozok megfelelője)."""
    pPr = par._p.get_or_add_pPr()
    bdr = OxmlElement("w:pBdr")
    bal = OxmlElement("w:left")
    bal.set(qn("w:val"), "single"); bal.set(qn("w:sz"), "24"); bal.set(qn("w:space"), "8"); bal.set(qn("w:color"), keret)
    bdr.append(bal); pPr.append(bdr)
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear"); shd.set(qn("w:color"), "auto"); shd.set(qn("w:fill"), szin)
    pPr.append(shd)

def cella_hatter(cella, szin):
    tcPr = cella._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear"); shd.set(qn("w:color"), "auto"); shd.set(qn("w:fill"), szin)
    tcPr.append(shd)

def doboz(doc, cim, elemek, szin, keret):
    if cim:
        p = doc.add_paragraph(); futasok(p, cim, alap_bold=True); arnyekol(p, szin, keret)
        p.paragraph_format.space_after = Pt(0)
    for x in elemek:
        p = doc.add_paragraph(); futasok(p, x); arnyekol(p, szin, keret)
        p.paragraph_format.space_after = Pt(0)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)

def docx_gyart():
    doc = Document()
    st = doc.styles["Normal"]
    st.font.name = "Segoe UI"; st.font.size = Pt(10.5)
    st.element.rPr.rFonts.set(qn("w:eastAsia"), "Segoe UI")
    for nev, meret in (("Heading 1", 16), ("Heading 2", 12.5)):
        s = doc.styles[nev]; s.font.name = "Segoe UI"; s.font.size = Pt(meret); s.font.color.rgb = NARANCS
    for sec in doc.sections:
        sec.left_margin = sec.right_margin = Cm(2); sec.top_margin = sec.bottom_margin = Cm(1.8)

    c = doc.add_heading(CIM, level=0)
    for r in c.runs: r.font.size = Pt(22); r.font.color.rgb = NARANCS
    p = doc.add_paragraph(ALCIM); p.runs[0].font.color.rgb = SZURKE
    p = doc.add_paragraph(FRISSITVE + " · A 📷 jelölés a később beillesztendő képernyőképek helye.")
    p.runs[0].font.size = Pt(9); p.runs[0].font.color.rgb = SZURKE

    for b in TARTALOM:
        tip = b[0]
        if tip == "bevezeto":
            doboz(doc, "A rendszer két része", ["• " + x for x in b[1]], "FFF4EE", "E4571B")
            p = doc.add_paragraph(); p.add_run("Tartalom").bold = True
            for x in TARTALOM:
                if x[0] == "h1":
                    q = doc.add_paragraph(x[1]); q.paragraph_format.left_indent = Cm(0.5)
                    q.paragraph_format.space_after = Pt(0)
        elif tip == "h1":  doc.add_heading(b[1], level=1)
        elif tip == "h2":  doc.add_heading(b[1], level=2)
        elif tip == "p":
            p = doc.add_paragraph(); futasok(p, b[1])
        elif tip in ("lepesek", "lista"):
            # Kézi számozás: a Word „List Number” stílusa a listák között nem kezdi újra a számozást.
            for n, x in enumerate(b[1], 1):
                p = doc.add_paragraph()
                pf = p.paragraph_format
                pf.left_indent = Cm(0.9); pf.first_line_indent = Cm(-0.6); pf.space_after = Pt(2)
                p.add_run(f"{n}.\t" if tip == "lepesek" else "•\t")
                futasok(p, x)
        elif tip == "tipp":      doboz(doc, None, ["💡 " + b[1]], "FDF7E3", "D9A441")
        elif tip == "figyelem":  doboz(doc, None, ["⚠️ " + b[1]], "FFF4EE", "E4571B")
        elif tip == "kep":
            p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            r = p.add_run("📷 Képernyőkép: " + b[1]); r.italic = True; r.font.color.rgb = SZURKE
        elif tip == "tabla":
            fej, sorok = b[1], b[2]
            t = doc.add_table(rows=1, cols=len(fej)); t.style = "Table Grid"
            for i, h in enumerate(fej):
                cl = t.rows[0].cells[i]; cl.text = ""
                futasok(cl.paragraphs[0], h, alap_bold=True); cella_hatter(cl, "F6EFE6")
            for s in sorok:
                cells = t.add_row().cells
                for i, x in enumerate(s):
                    cells[i].text = ""; futasok(cells[i].paragraphs[0], x)
            doc.add_paragraph().paragraph_format.space_after = Pt(0)
        elif tip == "osszegzes":
            doboz(doc, "Röviden, a napi rutin", ["• " + x for x in b[1]], "F5EFFB", "8A5CC7")
    return doc


if __name__ == "__main__":
    with open(os.path.join(GYOKER, "felhasznaloi-utmutato.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(html_gyart())
    docx_gyart().save(os.path.join(GYOKER, "felhasznaloi-utmutato.docx"))
    print("Kész: felhasznaloi-utmutato.html + felhasznaloi-utmutato.docx")
