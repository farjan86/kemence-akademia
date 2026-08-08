# Egyedi programok & Ajánlatok — funkcióterv

> Állapot: **IMPLEMENTÁLVA (2026-08-07)** — a teljes funkció (1–6. fázis) kész, és a **base-fájlokba beolvasztva** (`db/01-schema.sql`, `db/02-storage.sql`, `db/03-auto-visszaigazolo-trigger.sql` + `install.html`). A dev-migrációk (`m_10/m_11/m_12`) törölve.
> Készült: 2026-08-06. Ez a dokumentum a közösen egyeztetett tervet és a megvalósítást rögzíti. Egyetlen külső lépés maradt: a `send-ajanlat-email` Edge Function deploy + a trigger éles `<PROJECT_REF>`/`<ANON_KEY>` kitöltése (lásd install.html).

---

## 1. Cél és koncepció

A rendszerben mostantól **kétféle „program"** lesz:

| | **Listás programok** (meglévő) | **Egyedi programok** (új) |
|---|---|---|
| Mi | Konkrét időpontok, ár, létszám | Időpont nélküli ötletek: leánybúcsú, szülinap, csapatépítő, óvodás, családi rendezvény |
| A vendég | időpontra **foglal** | **ajánlatot kér** |
| Eredmény | foglalás (`bookings`) | ajánlat (`ajanlatok`) — **rendszeren kívüli** e-mailes egyeztetés |
| Admin nézet | Programok + Foglalások | Egyedi programok + Ajánlatok |

A két ág **külön él**: az egyedi programok NEM keverednek a listás programok közé, az ajánlatok NEM keverednek a foglalások közé.

---

## 2. Publikus oldal

- A jelenlegi **„Workshopjaink"** (statikus marketing-bemutató) blokk **teljesen átalakul „Egyedi programok"** blokká, és **lejjebb kerül**.
- Új főoldali sorrend:
  `hero → Élmény → Rólunk → Aktuális programok (foglalás) → Egyedi programok (ajánlat) → Webshop`
- Kártya-struktúra (mint eddig): **kép + cím + rövid leírás + „Részletek" (hosszú leírás modal)**.
- Minden kártya alatt: **„Kérjen egyedi ajánlatot"** gomb.
- A gomb egy **ajánlatkérő űrlapot** nyit (modal):
  - név, e-mail, telefon
  - létszám (hány fővel venne részt)
  - kívánt időpont (dátum + óra:perc) — lehet üres
  - „mit szeretne" — szabad szöveg
- **Kevés validáció** (e-mail/telefon formátum; a többi laza) — szándékosan lazább, mint a foglalásnál.
- Beküldés → új `ajanlatok` sor, státusz **`ajanlatra_var`**. A vendég sikerképernyőt lát, **és automatikus visszaigazoló e-mailt kap** („megkaptuk a kérésed, hamarosan válaszolunk").

---

## 3. Adatbázis

### `egyedi_programok` — a kártyák (időpont nélkül)

| mező | típus | megjegyzés |
|---|---|---|
| `id` | uuid PK | |
| `cim` | text | kötelező |
| `rovid_leiras` | text | a kártyán |
| `leiras` | text | hosszú, „Részletek" |
| `foto_url` | text | kép — a **meglévő publikus `program-fotok`** bucketbe (nem kell új bucket) |
| `archivalt` | bool | archiváltat nem mutatjuk a főoldalon |
| `sorrend` | int | megjelenítési sorrend (**új minta** — a Programok ábécé szerint rendez; itt kézi számmező) |
| `created_at` | timestamptz | |

### `ajanlatok` — a kérések + a válasz

| mező | típus | megjegyzés |
|---|---|---|
| `id` | uuid PK | |
| `azonosito` | bigint identity (1-től) | megjelenített **előtag + kezdőszám a `settings`-ből állítható** (külön az ajánlatoknak, pl. `A-`; ne keveredjen az F-100 foglalásokkal) |
| `egyedi_program_id` | uuid FK → egyedi_programok (nullable) | melyik ötletre; üres = általános |
| `nev` · `email` · `telefon` | text | vendég |
| `letszam` | int | hány fő (a kéréskor megadott, laza) |
| `kivant_idopont` | timestamptz (nullable) | a vendég kívánt időpontja |
| `keres_szoveg` | text | „mit szeretne" |
| `statusz` | text | `ajanlatra_var` / `ajanlat_kikuldve` / `elfogadva` / `elutasitva` / `lemondva` |
| `belso_jegyzet` | text (nullable) | **privát** admin-jegyzet — a vendég sosem látja |
| **`vegleges_idopont`** | timestamptz (nullable) | **elfogadáskor kötelező** |
| **`vegleges_letszam`** | int (nullable) | **elfogadáskor kötelező** |
| **`vegleges_ar`** | int (nullable) | **elfogadáskor kötelező** (naptár/statisztika, levélbe is) |
| **`ajanlat_szoveg`** | text (nullable) | **elfogadáskor kötelező** — lehet „Ajánlat a csatolmány szerint" |
| **`csatolmany_url`** | text (nullable) | **opcionális** Storage-fájl (pdf/docx/txt/…) |
| `valasz_elkuldve` | timestamptz (nullable) | mikor ment ki a döntésről szóló e-mail |
| `created_at` | timestamptz | |

> **Megjegyzés a koncepcióváltáshoz:** a régi `valasz_html` (formázott ajánlat a rendszerben) **kikerült**. Az ajánlatot a szervező **rendszeren kívül, külön e-mailben** egyezteti; a rendszer csak az elfogadáskori végleges adatokat + az opcionális csatolmányt tárolja.

> **Adatintegritás (CHECK):** a projekt stílusában named CHECK véd a félkész „elfogadva" ellen:
> `check (statusz <> 'elfogadva' or (vegleges_idopont is not null and vegleges_letszam is not null and vegleges_ar is not null and ajanlat_szoveg is not null))`.
> Így az űrlap-validáción túl a DB is garantálja, hogy elfogadott ajánlatnál a 4 mező ki van töltve.

### `ajanlat_log` — külön naplótábla (nem az `email_log`)

A foglalás-levelek naplója (`email_log`) `booking_id`-hoz van kötve (NOT NULL FK), ezért **nem használható** ajánlat-levelekhez. Teljesen **külön** naplótábla:

| mező | típus | megjegyzés |
|---|---|---|
| `id` | bigint identity PK | mint az `email_log` |
| `ajanlat_id` | uuid FK → ajanlatok (on delete cascade) | |
| `tipus` | text | melyik sablon ment ki |
| `cimzett` | text | tényleges címzett |
| `elkuldve` | timestamptz | default now() |

### `ajanlat_sablonok` — külön sablontábla (nem az `email_sablonok`)

A függetlenség elve miatt az ajánlat-sablonok **saját táblában** élnek (a foglalás `email_sablonok`-ját nem bővítjük, a CHECK-listáját nem piszkáljuk). Szerkezet azonos: `tipus text primary key check (...)`, `targy`, `torzs`, `updated_at`. Öt sablon (lásd 7.).

### RLS (hozzáférés)
- `egyedi_programok`: **anon olvas** (`using(true)`, az archiváltat app-oldalon szűrjük — pont mint a `workshops`), admin mindent ír/olvas.
- `ajanlatok`: **anon csak INSERT** (`with check (statusz = 'ajanlatra_var')`), **nem olvashat** (privát, mint a `bookings`); admin lát + módosít mindent.
- `ajanlat_log`, `ajanlat_sablonok`: **admin-only** (a naplót a service-role Edge Function írja, RLS-t megkerülve — mint az `email_log`).
- **Csatolmány Storage-bucket:** **privát** (nem publikus); csak az admin tölt fel/olvas, a `send-ajanlat-email` service-role kulccsal fér hozzá.
- `egyedi_programok` **fotó**: a **meglévő publikus `program-fotok`** bucket (nem kell új).

### Settings-kiegészítés
- Két új `settings` mező az **ajánlat-azonosítóhoz** (`ajanlat_azonosito_elotag` + `ajanlat_azonosito_kezdo`), a foglalás-azonosítóhoz hasonlóan — az adminban állítható. Külön `azonAjanlat()` segéd a megjelenítéshez (a `azon()` mintájára).

### Elnevezés
- Migráció: eredetileg **`db/m_10-ajanlatok.sql`** (dev-migráció) — **már beolvadt a `db/01-schema.sql`-be**, a fájl törölve.
- Az ajánlat auto-visszaigazoló + csapat-értesítő **külön INSERT-trigger** az `ajanlatok`-on (a `03-auto-visszaigazolo-trigger.sql` mintájára, de a `send-ajanlat-email`-t hívja).

---

## 4. Ajánlat életciklusa (státuszok)

```
AJÁNLATRA VÁR ──► AJÁNLAT KIKÜLDVE ──► ELFOGADVA ──► LEMONDVA
 (beérkezik)       (admin válaszol)         │         (vendég v. szervező,
      │                  │                  │          elfogadás UTÁN is)
      └──────────────────┴──────────────────┴─► ELUTASÍTVA / LEMONDVA
                                               (bármely fázisból)
```

- **Ajánlatra vár:** friss ajánlatkérés, még nincs válasz.
- **Ajánlat kiküldve:** **csak állapotjelző** — az admin a rendszeren **kívül**, külön e-mailben adott ajánlatot, és jelzi, hogy várja a választ. A rendszer itt **nem küld** levelet.
- **Elfogadva:** a vendég igent mondott. Az admin a gomb megnyomásakor rögzíti a **végleges időpontot, létszámot, árat és az ajánlat-szöveget** (+ opcionális csatolmány), majd **kézzel** kiküldi a megerősítő e-mailt. → **ekkor kerül be a naptárba.**
- **Elutasítva / Lemondva:** bármelyik oldalról kezdeményezhető (vendég vagy szervező, **ahogy a programnál is**), és **bármely fázisból** — beleértve az **elfogadás utáni lemondást** is. Ilyenkor az ajánlat **kikerül a naptárból** (vagy „lemondva" jelöléssel jelenik meg). Az admin egy kattintással állítja + **kézzel** küldheti a megfelelő értesítőt.

---

## 5. Admin felület

### Menü — vizuális elkülönítés
A menü két csoportra tagolódik:

```
IDŐPONTOS              EGYEDI
· Programok            · Egyedi programok
· Foglalások           · Ajánlatok
· Naptár
```
(pl. elválasztó + halvány csoportcímke, esetleg eltérő akcentszín az „Egyedi" ágnak.)

### „Egyedi programok" nézet
- Ugyanaz, mint a „Programok", csak **időpont nélkül**: kép + cím + rövid/hosszú leírás + sorrend + **archiválás**.
- Amit felviszel, megjelenik a főoldalon; amit archiválsz, lekerül.

### „Ajánlatok" nézet
- A beérkezett ajánlatkérések **listája**: azonosító, vendég (név/tel/e-mail), létszám, kívánt időpont, melyik egyedi programra, státusz.
- Státusz szerinti szűrés/alfülek (Ajánlatra vár / Kiküldve / Elfogadva / Lezárt) — a Foglalások fül-mintája.
- Soronként: **státusz-műveletek** (Ajánlat kiküldve / Elfogad / Elutasít / Lemond) + a levél-modal (a Foglalások „✉ Levél" mintája) + az **elfogadás-űrlap** (lásd 6.).

### Beállítások — a sablonok látványos szétválasztása
A Settings e-mail-sablon szekciója **két, vizuálisan elkülönített csoportra** bomlik, hogy soha ne keveredjen a kétféle levél:

```
┌─ FOGLALÁSI e-mailek ─────────────────────┐
│ Visszaigazolás · Jóváhagyás · Elutasítás │
│ Lemondás · Csapat-értesítő · …           │
└──────────────────────────────────────────┘
──────────────  vízszintes elválasztó  ──────────────
┌─ AJÁNLATI e-mailek ──────────────────────┐
│ Visszaigazolás · Csapat-értesítő ·       │
│ Megerősítés · Elutasítás · Lemondás      │
└──────────────────────────────────────────┘
```
- **Vízszintes elválasztó vonal** + **külön csoportcím** (kiemelt fejléc) a két blokk közé.
- A foglalási sablonok az `email_sablonok`-ból, az ajánlatiak az `ajanlat_sablonok`-ból töltődnek — két külön renderelő, egy képernyőn, jól láthatóan elválasztva.

---

## 6. Elfogadás és státusz-műveletek (egyszerűsített irány)

**Az ajánlatot a szervező a rendszeren KÍVÜL, külön e-mailben egyezteti** a vendéggel. A rendszerben nincs formázott szöveg-/táblázat-szerkesztő — így a korábbi terv legkockázatosabb pontja teljesen kiesik. A rendszer feladata csak az **állapot** és az **elfogadáskori végleges adatok** rögzítése, illetve a **kész sablonlevelek** kiküldése.

### Az „Elfogadva" művelet — űrlap (minden mező kötelező, kivéve a csatolmányt)
| mező | típus | kötelező |
|---|---|---|
| végleges időpont (`vegleges_idopont`) | dátum + óra | ✅ |
| végleges létszám (`vegleges_letszam`) | szám | ✅ |
| végleges ár (`vegleges_ar`) | szám (Ft) | ✅ |
| ajánlat szövege (`ajanlat_szoveg`) | szöveg | ✅ — lehet „Ajánlat a csatolmány szerint" |
| csatolmány (`csatolmany_url`) | fájl (pdf/docx/txt/…) → Storage | ⬜ opcionális |

- Mentés után a státusz **`elfogadva`**, és megjelenik a **„Megerősítő e-mail küldése"** gomb.
- A megerősítő levélbe **bemegy a 4 végleges adat** (időpont, létszám, ár, ajánlat-szöveg), és **ha van csatolmány, azt is mellékeli**.

### Elutasítás / Lemondás
- Egy-egy gomb (`Elutasít` / `Lemond`) → státusz beáll, és **kézzel** kiküldhető a megfelelő értesítő sablonlevél.

### Csatolmány (Storage)
- Külön, **privát** Storage-bucket az ajánlat-csatolmányoknak (a `foto_url`-höz hasonló feltöltési minta).
- A levélhez a `send-email` a fájlt aláírt/olvasható URL-lel vagy base64-gyel csatolja (a Resend támogatja).

---

## 7. E-mail — teljesen független ágon

**Elv:** az ajánlat-levelezés **nem nyúl a foglalás küldőjéhez**. Külön Edge Function, külön sablontábla, külön naplótábla, külön trigger. Így a `bookings`-oldal érintetlen marad (nulla regressziós kockázat), és a webhook-payloadok sem keverednek össze.

### Külön Edge Function: `send-ajanlat-email`
- A `send-email` (foglalás) mintájára, de **önállóan**: az `ajanlatok`-ból olvas, az `ajanlat_sablonok`-ból veszi a sablont, az `ajanlat_log`-ba naplóz.
- Ugyanazok a módok: **webhook** (INSERT → auto visszaigazoló + csapat-értesítő) és **kézi** (`{ ajanlat_id, tipus, (targy, torzs) }`).
- *(Alternatíva volt egy közös függvény `table` megkülönböztetéssel — de a te „legyen független" elved szerint a külön függvény a tisztább; picit több infra-duplikáció a `kuld()`/CORS/`DEV_REDIRECT_TO` körül, cserébe zéró ütközés.)*

### Öt sablon (az `ajanlat_sablonok` táblában)
| sablon | mikor | kinek | küldés |
|---|---|---|---|
| `ajanlat_visszaigazolas` | ajánlatkérés beérkezik | vendég | **auto** |
| `ajanlat_csapat_ertesito` | ajánlatkérés beérkezik | csapat | **auto** |
| `ajanlat_megerosites` | elfogadás | vendég | **kézi** (4 végleges adat + opc. csatolmány) |
| `ajanlat_elutasitas` | elutasítás | vendég | **kézi** |
| `ajanlat_lemondas` | lemondás | vendég | **kézi** |

- Behelyettesíthető mezők: `{nev}`, `{azonosito}`, `{vegleges_idopont}`, `{vegleges_letszam}`, `{vegleges_ar}`, `{ajanlat_szoveg}` stb.
- Feladó/Reply-To: a meglévő rendszer szerint (csapat e-mail a `settings.levelezesi_email`-ből).

### Csatolmány
- A **privát** bucketből a fájlt **base64-ként** adjuk át a Resend `attachments`-nek (a privát URL-t a Resend nem érné el; a service-role letölti, base64-eli).
- Feltöltéskor **méret- és típus-korlát** (pl. ≤ ~10 MB; pdf/docx/txt/kép) — a „bármilyen fájl" biztonsági/limit okból szűrve.

---

## 8. Naptár és jelentés

- **Csak az `elfogadva` státuszú ajánlat** kerül a naptárba — ekkorra már van **végleges időpont** (`vegleges_idopont`), tehát „van időpontja". (Lemondáskor kikerül / „lemondva" jelölést kap.)
- **Technikai megjegyzés:** a naptár ma az `idopontok` táblából rajzol (egy esemény = egy időpont-sor). Az elfogadott ajánlat **nem** `idopontok`-sor — önálló esemény a `vegleges_idopont`-tal. Ezért a naptár **második eseményforrást** kap: beolvassa az elfogadott ajánlatokat is, és önálló eseményként rendeli hozzá a naphoz. Ez a #3-as pont: fogalmilag egyszerű (csak elfogadott, csak a végleges idő), de kódban egy külön betöltő + külön kattintás-viselkedés (nincs létszám-lista, a részletpanel a végleges adatokat mutatja).
- **Vizuálisan egyértelműen elkülönül** a foglalásoktól: eltérő akcentszín (lila/borostyán) + jelölő (✨ / „Egyedi"). A megkülönböztetés a **naptár-nézetben és a részletpanelen** is érvényes.
- **Jelentés/export:** a foglalás-export idopont-, illetve foglalás-alapú — az ajánlatok **saját export-ágat** kapnak (külön szekció / külön jelölés), nem keverednek a foglalások közé.

---

## 9. Megvalósítás — fázisokban

1. **DB** — `egyedi_programok`, `ajanlatok`, `ajanlat_log`, `ajanlat_sablonok` táblák + integritás-CHECK + RLS + 2 új `settings` mező + privát csatolmány-bucket + `ajanlatok` INSERT-trigger. Mind `db/m_10-ajanlatok.sql`-be, majd `01-schema.sql`-be olvasztva.
2. **Publikus** — Egyedi programok blokk (a Workshopjaink helyén, lejjebb) + ajánlatkérő űrlap (új `web/js/ajanlat.js`, a `db` + `util.js` újrahasznosításával).
3. **Admin — Egyedi programok** menü (CRUD + kép a `program-fotok` bucketbe + archiválás + `sorrend`).
4. **Admin — Ajánlatok** menü: lista + státusz-fülek + **elfogadás-űrlap** (4 kötelező mező + opcionális csatolmány) + levél-modal.
5. **E-mail** — külön **`send-ajanlat-email`** Edge Function + 5 sablon (`ajanlat_sablonok`) + `ajanlat_log` + **csatolmány (base64)**. Settings: a sablonok látványos szétválasztása.
6. **Naptár + export** — elfogadott ajánlatok második eseményforrásként (`vegleges_idopont`) + saját export-ág.

---

## 10. Megvalósíthatóság

- **Adatbázis, publikus űrlap, admin listák:** rutinmunka a meglévő minták alapján. ✅
- **A korábbi egyetlen valós kockázat** (formázott válasz-szerkesztő + HTML-táblázat e-mailben) a rendszeren kívüli egyeztetéssel **teljesen kiesett**. ✅
- **Három pont, amit a valós kód alapján nem szabad alábecsülni** (nem kockázat, csak valós munka):
  1. **`send-ajanlat-email`** — önálló Edge Function (webhook + kézi mód + `ajanlat_log` + base64 csatolmány).
  2. **Naptár** — az elfogadott ajánlat nem `idopontok`-sor → **második eseményforrás** + külön részletpanel + külön export-ág.
  3. **Naplózás/sablonok** — külön `ajanlat_log` és `ajanlat_sablonok` tábla (az `email_log`/`email_sablonok` a foglaláshoz kötött).
- **Csatolmány:** base64 a Resendnek + méret-/típus-korlát. ✅
- **Validáció:** a publikus ajánlatkérésnél szándékosan lazább; az elfogadás-űrlapon a 4 végleges mező **kötelező** (app-oldal + DB CHECK).

---

## 11. Eldöntött részletek (2026-08-06)

- **Azonosító:** olvasható, a `settings`-ből **állítható előtaggal + kezdőszámmal** (külön az ajánlatoknak, pl. `A-`).
- **Automatikus visszaigazoló:** a vendég **kap** „megkaptuk a kérésed" e-mailt beküldéskor (`ajanlat_visszaigazolas` sablon).
- **Belső jegyzet:** **van** privát admin-jegyzet mező (`belso_jegyzet`), a vendég nem látja.
- **Véglegesített létszám + ár:** elfogadáskor **külön mezőben** rögzül (`vegleges_letszam`, `vegleges_ar`) — a naptár/statisztika egységes kezeléséhez.

### Koncepcióváltás (2026-08-07)

- **Rendszeren kívüli egyeztetés:** az ajánlatot a szervező **külön e-mailben** adja; a rendszerben **nincs** formázott szöveg-/táblázat-szerkesztő és `valasz_html`. → a korábbi fő kockázat kiesett.
- **„Ajánlat kiküldve" = csak állapotjelző** (a rendszer itt nem küld levelet).
- **Elfogadás-űrlap — 4 kötelező mező:** `vegleges_idopont`, `vegleges_letszam`, `vegleges_ar`, `ajanlat_szoveg` (utóbbi lehet „Ajánlat a csatolmány szerint").
- **Csatolmány:** **opcionális** fájl (pdf/docx/txt/…) privát Storage-bucketben; a megerősítő levélhez mellékelhető.
- **E-mail sablonok (4):** `ajanlat_visszaigazolas` (auto), `ajanlat_megerosites`, `ajanlat_elutasitas`, `ajanlat_lemondas` (utóbbi három kézzel küldve).
- **`send-email` bővítés:** `ajanlatok`-ág + Resend csatolmány-támogatás.

### Kód-átvizsgálás utáni döntések (2026-08-07 — a valós kódhoz mérve)

- **Teljes függetlenség a foglalástól** (vezérelv): az ajánlat-ág nem nyúl a `bookings`/`send-email`/`email_sablonok`/`email_log`-hoz.
- **Külön `ajanlat_log` tábla** (az `email_log` `booking_id`-hoz kötött, nem használható).
- **Külön `ajanlat_sablonok` tábla** + **külön `send-ajanlat-email` Edge Function** (nem közös ág — nulla ütközés/regresszió).
- **Csapat-értesítő is kell** bejövő ajánlatnál (`ajanlat_csapat_ertesito`) → **5 sablon** összesen. Mind az ajánlat-oldali visszaigazoló is **teljesen független** a foglalás visszaigazolójától.
- **Elfogadás után is lemondható** (vendég vagy szervező, mint a programnál) → ilyenkor kikerül a naptárból.
- **Naptár:** csak elfogadott ajánlat, `vegleges_idopont`-tal, **második eseményforrásként** (nem `idopontok`-sor) + saját export-ág.
- **Egyedi programok fotó:** a meglévő **publikus `program-fotok`** bucket; a privát bucket csak az ajánlat-csatolmányoké.
- **Csatolmány:** base64-ként a Resendnek; feltöltéskor méret-/típus-korlát.
- **Integritás:** named CHECK garantálja, hogy `elfogadva` státusznál a 4 végleges mező ki van töltve.
- **Settings:** a foglalási és az ajánlati e-mail-sablonok **vízszintes elválasztóval + kiemelt csoportcímmel** külön blokkban.
