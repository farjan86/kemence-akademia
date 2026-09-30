# Kemence Akadémia — JS modulok (frontend felépítés)

> A frontend **build nélküli**, klasszikus `<script>`-ekből áll (nincs framework,
> nincs bundler, nincs ES-module import/export). A fájlok a **közös globális
> scope-ban** élnek: az egyik fájlban deklarált `const`/`let`/függvény a később
> betöltött fájlokból is látszik. Ezért **a betöltési sorrend számít** (a HTML-ben
> `defer`-rel, ami megőrzi a sorrendet).
>
> Utolsó frissítés: 2026-09-30 (az Előadóink és a Partnerek után).

---

## Publikus oldal — `web/js/`

Betöltési sorrend (a `web/index.html` végén):
`config.js` → `util.js` → `dialog.js` → `app.js` → `eloadok.js` → `foglalas.js` → `ajanlat.js` → `szikrak.js` → `reveal.js`

| Fájl | Felelősség |
|---|---|
| **`config.js`** | A Supabase **Project URL** + **anon** kulcs (publikus; RLS véd). Ezt kell kitölteni telepítéskor. |
| **`dialog.js`** | Saját felugró ablak (`dialog.uzen` / `dialog.megerosit` / `dialog.valaszt`) a böngésző `alert`/`confirm` helyett. Az adminnal közös (`../js/dialog.js`). |
| **`util.js`** | **Tiszta segédek** (nincs DB/DOM-állapot): `HUF`, `formatDatum`, `formatDatumRovid`, `lezarultNap`, `escapeHtml`, `tisztitHtml` (rich-text tisztító), telefon/e-mail validáció, domain-elgépelés felismerés. Az `app.js` és a `foglalas.js` is használja. |
| **`app.js`** | **Adat + programok kirajzolása.** Supabase kliens (`db`), a `programok` nézet betöltése, **programonkénti csoportosítás** (egy program = egy kártya, több **időpont-csempével**), a „Részletek" ablak, a látogatás-számláló, az indítás. Közös állapot: `programLista`, `idopontIndex`. |
| **`eloadok.js`** | **Előadóink.** Betölti a nem rejtett előadókat, kirajzolja a névsort a **Rólunk** szakaszban, és adja a program-kártyák „Előadó: …" sorát (`eloadoSorHtml`, a nézet `eloadok` JSON mezőjéből). A névre kattintva nyitja a **bemutatkozó ablakot** (fotó + formázott szöveg). Rejtett előadó neve a kártyán látszik, de nem kattintható. Közös állapot: `eloadoMap`. |
| **`foglalas.js`** | **A foglalási ablak.** A csempére kattintva a kiválasztott **időpontra** ír foglalást (`idopont_id`), validációval; siker után frissíti a listát. A **számlázási cím** három mezője itt kötelező (a DB-trigger is ellenőrzi). Használja az `app.js` állapotát (`idopontIndex`, `betoltProgramok`, `db`). |
| **`ajanlat.js`** | **Az EGYEDI ág publikus oldala.** Az `egyedi_programok` kirajzolása, a „Részletek" ablak, és az **ajánlatkérő űrlap** (kívánt időpont, létszám, üzenet + a kötelező számlázási cím) beküldése az `ajanlatok` táblába. |
| **`szikrak.js`** | Parázs-szikra háttéranimáció `<canvas>`-on. **`prefers-reduced-motion: reduce` esetén el sem indul** — ha a szikrák „nem mennek", először ezt nézd. |
| **`reveal.js`** | A szekciók finom beúszása görgetéskor (IntersectionObserver); csökkentett mozgásnál azonnal láthatóvá tesz mindent. |

---

## Admin oldal — `web/admin/js/`

Betöltési sorrend (a `web/admin/index.html` végén):
`../js/config.js` → `../js/dialog.js` → `util.js` → `core.js` → `foglalasok.js` → `programok.js` → `egyediprogramok.js` → `ajanlatok.js` → `naptar.js` → `eloadok.js` → `partnerek.js` → `beallitasok.js`

| Fájl | Felelősség |
|---|---|
| **`util.js`** | **Tiszta segédek + konstansok:** `formatDatum`, `HUF`, `isoToLocalInput`, `idoOf`/`progOf` (a `bookings → idopontok → workshops` join elérői), `masodlagos` (idő­állapot), `STAT`, `muveletek`, `EMAIL_CIMKE`, validáció, `escapeHtml`, `tisztitHtml`, `loadScript` (CDN igény szerint), és a közös `BOOKING_SELECT`. |
| **`core.js`** | **A mag.** Supabase kliens (`db`), belépés/kilépés (Auth), nézetváltás (login ↔ admin), **fülváltás** (`valtTab`), és a **közös állapot**: `beall`, `naptarNezet`, `emailLogMap`, `programok`, `osszesFoglalas`. Közös adatbetöltők: `betoltBeallitasok`, `betoltEmailLog`, `betoltProgramok`. Az `azon()` (megjelenített azonosító). |
| **`foglalasok.js`** | **Foglalások fül:** lista + szűrő + státusz-fülek, sor-render, Excel-export, „✉ Levél" (sablon-előnézet + küldés a `send-email`-lel), megjegyzés-ablak, **státuszváltás**, és a **foglalás-szerkesztő** — benne a **másik időpontra áthelyezés** (csak azonos árú, nem elmaradt időpontok). |
| **`programok.js`** | **Programok fül:** program-lista (Aktuális/Archivált) az időpontok bontásával, és a **több-időpontos szerkesztő** — program-mezők (cím, leírások, kép) + **előadó-választó** (jelölőnégyzetek az `eloadok` táblából; mentéskor a `program_eloadok` kapcsolatok szinkronizálása) + dinamikus **időpont-sorok** (dátum/ár/kedvezményes ár/létszám/állapot), mentéskor az időpontok szinkronizálása (insert/update/delete), törlés/archiválás/visszaállítás. |
| **`egyediprogramok.js`** | **Egyedi programok fül:** az ajánlatkérhető kínálat (leánybúcsú, csapatépítő…) — lista, szerkesztő (cím, leírások, kép), húzásos sorrend, archiválás/törlés. Időpont és ár nincs. |
| **`ajanlatok.js`** | **Ajánlatok fül:** az ajánlatkérések listája + státusz-fülek, a **Részletek** ablak (kérés adatai, számlázási cím, privát belső jegyzet), az **ajánlat összeállítása** (végleges időpont/létszám/összár/szöveg + csatolmány a privát bucketbe) és kiküldése, státuszváltás, Excel-export. |
| **`naptar.js`** | **Naptár fül:** minden **időpont külön esemény**; lista- és rács-nézet (magyar ünnepekkel), évi/havi összesítő, egy időpont lenyitása (élő foglalások, számok) és **PDF-jelentés** (pdfmake). |
| **`eloadok.js`** | **Előadóink fül (Csapat csoport):** az előadók egyszerű listája, szerkesztő (név, formázható bemutatkozás, fénykép), húzásos sorrend, **Rejtés/Megjelenítés**, és **Törlés — csak ha az előadó egyetlen programhoz sincs kötve** (a soron „N program" jelzés mutatja a kapcsolatok számát; a DB `on delete restrict`-je is véd). |
| **`partnerek.js`** | **Partnerek képernyő** (a Naptár melletti gomb): a **meglévő** foglalásokból és ajánlatokból épülő, **e-mail cím szerint összevont** lista — oszloponkénti kereső, időszak-szűrő, „csak megvalósult" kapcsoló, alkalmak száma + **Visszatérő** jelvény, sor lenyitása, Excel-export, szűrő-törlés. Az azonosítóra kattintva **helyben** nyílik meg a foglalás szerkesztője / az ajánlat részletei (nem vált fület). |
| **`beallitasok.js`** | **Beállítások fül, három alfüllel:** *Általános* (csapat e-mail, foglalási és ajánlati info-sáv, naptár nézet), *Nyilvános programok* (azonosító-formátum + foglalási levélsablonok), *Egyedi megrendelések* (ajánlat-azonosító + ajánlat-sablonok). |

### Hogyan osztoznak az állapoton
- A **több modul által használt** mutálható állapot a **`core.js`-ben** él (`db`, `osszesFoglalas`, `programok`, `emailLogMap`, `beall`, `naptarNezet`). A többi modul ezeket olvassa/írja a közös globális scope-on át.
- A **Partnerek** képernyő nem tart saját adatot: a `foglalasok.js` és az `ajanlatok.js` már betöltött listáiból dolgozik, és szükség esetén maga kéri be őket, mielőtt megnyitna egy sort.
- A **kereszthivatkozások futásidőben** oldódnak fel (pl. a `core.js` `frissitNezet`-je a `foglalasok.js` `betoltFoglalasok`-ját hívja) — ezért elég, ha a hívott függvény a **hívás pillanatában** létezik (addigra minden modul betöltött).

### Új admin-modul hozzáadása
1. Hozz létre egy új fájlt a `web/admin/js/` alatt.
2. Vedd fel a `web/admin/index.html` végén a `<script src="js/uj.js" defer></script>` sort a **megfelelő sorrendbe** (a `core.js` után, ha a közös állapotra épül).
3. A csak több modulban használt közös állapotot a `core.js`-be tedd.

---

## Kapcsolódó
- Backend/DB/e-mail: `docs/technikai-dokumentacio.md`, `docs/email.md`.
- A „több időpont" átalakítás terve/döntései: `docs/tobb-idopont-terv.md`.
