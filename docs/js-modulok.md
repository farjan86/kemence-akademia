# Kemence Akadémia — JS modulok (frontend felépítés)

> A frontend **build nélküli**, klasszikus `<script>`-ekből áll (nincs framework,
> nincs bundler, nincs ES-module import/export). A fájlok a **közös globális
> scope-ban** élnek: az egyik fájlban deklarált `const`/`let`/függvény a később
> betöltött fájlokból is látszik. Ezért **a betöltési sorrend számít** (a HTML-ben
> `defer`-rel, ami megőrzi a sorrendet).
>
> Utolsó frissítés: 2026-08-04 (a „több időpont" átalakítás után).

---

## Publikus oldal — `web/js/`

Betöltési sorrend (a `web/index.html` végén):
`config.js` → `util.js` → `dialog.js` → `app.js` → `foglalas.js`

| Fájl | Felelősség |
|---|---|
| **`config.js`** | A Supabase **Project URL** + **anon** kulcs (publikus; RLS véd). Ezt kell kitölteni telepítéskor. |
| **`dialog.js`** | Saját felugró ablak (`dialog.uzen` / `dialog.megerosit` / `dialog.valaszt`) a böngésző `alert`/`confirm` helyett. Az adminnal közös (`../js/dialog.js`). |
| **`util.js`** | **Tiszta segédek** (nincs DB/DOM-állapot): `HUF`, `formatDatum`, `formatDatumRovid`, `lezarultNap`, `escapeHtml`, `tisztitHtml` (rich-text tisztító), telefon/e-mail validáció, domain-elgépelés felismerés. Az `app.js` és a `foglalas.js` is használja. |
| **`app.js`** | **Adat + programok kirajzolása.** Supabase kliens (`db`), a `programok` nézet betöltése, **programonkénti csoportosítás** (egy program = egy kártya, több **időpont-csempével**), a „Részletek" ablak, a látogatás-számláló, az indítás. Közös állapot: `programLista`, `idopontIndex`. |
| **`foglalas.js`** | **A foglalási ablak.** A csempére kattintva a kiválasztott **időpontra** ír foglalást (`idopont_id`), validációval; siker után frissíti a listát. Használja az `app.js` állapotát (`idopontIndex`, `betoltProgramok`, `db`). |

---

## Admin oldal — `web/admin/js/`

Betöltési sorrend (a `web/admin/index.html` végén):
`../js/config.js` → `../js/dialog.js` → `util.js` → `core.js` → `foglalasok.js` → `programok.js` → `naptar.js` → `beallitasok.js`

| Fájl | Felelősség |
|---|---|
| **`util.js`** | **Tiszta segédek + konstansok:** `formatDatum`, `HUF`, `isoToLocalInput`, `idoOf`/`progOf` (a `bookings → idopontok → workshops` join elérői), `masodlagos` (idő­állapot), `STAT`, `muveletek`, `EMAIL_CIMKE`, validáció, `escapeHtml`, `tisztitHtml`, `loadScript` (CDN igény szerint), és a közös `BOOKING_SELECT`. |
| **`core.js`** | **A mag.** Supabase kliens (`db`), belépés/kilépés (Auth), nézetváltás (login ↔ admin), **fülváltás** (`valtTab`), és a **közös állapot**: `beall`, `naptarNezet`, `emailLogMap`, `programok`, `osszesFoglalas`. Közös adatbetöltők: `betoltBeallitasok`, `betoltEmailLog`, `betoltProgramok`. Az `azon()` (megjelenített azonosító). |
| **`foglalasok.js`** | **Foglalások fül:** lista + szűrő + státusz-fülek, sor-render, Excel-export, „✉ Levél" (sablon-előnézet + küldés a `send-email`-lel), megjegyzés-ablak, **státuszváltás**, és a **foglalás-szerkesztő** — benne a **másik időpontra áthelyezés** (csak azonos árú, nem elmaradt időpontok). |
| **`programok.js`** | **Programok fül:** program-lista (Aktuális/Archivált) az időpontok bontásával, és a **több-időpontos szerkesztő** — program-mezők (cím, leírások, **előadó**, kép) + dinamikus **időpont-sorok** (dátum/ár/kedvezményes ár/létszám/állapot), mentéskor az időpontok szinkronizálása (insert/update/delete), törlés/archiválás/visszaállítás. |
| **`naptar.js`** | **Naptár fül:** minden **időpont külön esemény**; lista- és rács-nézet (magyar ünnepekkel), évi/havi összesítő, egy időpont lenyitása (élő foglalások, számok) és **PDF-jelentés** (pdfmake). |
| **`beallitasok.js`** | **Beállítások fül:** általános beállítások (csapat e-mail, info-sáv, naptár nézet), az **azonosító-formátum**, és az **e-mail sablonok** szerkesztése. |

### Hogyan osztoznak az állapoton
- A **több modul által használt** mutálható állapot a **`core.js`-ben** él (`db`, `osszesFoglalas`, `programok`, `emailLogMap`, `beall`, `naptarNezet`). A többi modul ezeket olvassa/írja a közös globális scope-on át.
- A **kereszthivatkozások futásidőben** oldódnak fel (pl. a `core.js` `frissitNezet`-je a `foglalasok.js` `betoltFoglalasok`-ját hívja) — ezért elég, ha a hívott függvény a **hívás pillanatában** létezik (addigra minden modul betöltött).

### Új admin-modul hozzáadása
1. Hozz létre egy új fájlt a `web/admin/js/` alatt.
2. Vedd fel a `web/admin/index.html` végén a `<script src="js/uj.js" defer></script>` sort a **megfelelő sorrendbe** (a `core.js` után, ha a közös állapotra épül).
3. A csak több modulban használt közös állapotot a `core.js`-be tedd.

---

## Kapcsolódó
- Backend/DB/e-mail: `docs/technikai-dokumentacio.md`, `docs/email.md`.
- A „több időpont" átalakítás terve/döntései: `docs/tobb-idopont-terv.md`.
