# Terv — több időpont egy programhoz

**Állapot:** TERVEZÉS KÉSZ — a megrendelői döntések véglegesítve. Kód még nem készült.
Utolsó frissítés: 2026-08-04.
**Környezet:** fejlesztői (dev). Nincs éles működés, az adat szabadon törölhető.

---

## 1) A megrendelő igénye

Egy adott programhoz (workshophoz) **több időpontot** is lehessen rögzíteni. Ha
ugyanabból a workshopból több időpont van, ne kelljen a programot többször felvinni —
**egy program legyen, több időpontra lehessen jelentkezni**.

Elvárt megjelenés:
- **Admin – program-szűrő és naptár:** az időpontok **külön programként** jelenjenek meg.
- **Publikus foglalási oldal:** egy programhoz **több időpont-lehetőség** látszódjon.
- **Program módosítás:** az **időpontokat** lehessen szerkeszteni.

---

## 2) A megoldás: egy-a-többhöz szétbontás

Jelenleg az időpont magában a programban van (`workshops.idopont`), ezért „egy program
= egy időpont". A megoldás: az időpontot kiemeljük egy **külön táblába**, ami a programra
mutat, és a **foglalás a konkrét időpontra** hivatkozik.

```
   MOST                              EZUTÁN
   ┌──────────────┐                 ┌──────────────┐        ┌────────────────────┐
   │  workshops   │                 │  workshops   │ 1    ∞ │     idopontok      │
   │  (program)   │                 │  (program)   │───────▶│  (egy alkalom)     │
   │  + idopont   │                 │  cím, leírás,│        │  idopont           │
   │  + ar        │                 │  kép, ...    │        │  ar, kedvezmenyes  │
   │  + max_lét   │                 │              │        │  max_letszam       │
   └──────┬───────┘                 └──────────────┘        │  statusz(aktiv/    │
          │                                                 │         elmaradt)  │
          │ ∞                                               └─────────┬──────────┘
   ┌──────▼───────┐                                          ┌────────▼─────┐
   │   bookings   │   workshop_id  ─── átáll ──▶             │   bookings   │  idopont_id
   └──────────────┘                                          └──────────────┘
```

---

## 3) Véglegesített döntések (megrendelői válaszokkal)

| Kérdés | Döntés |
|---|---|
| **Ár** időpontonként eltérhet? | **IGEN** → `ar` **és** `kedvezmenyes_ar` az `idopontok`-hoz kerül |
| **Max. létszám** hol? | Az `idopontok`-hoz (jellemzően azonos, de **rugalmasan** időpontonként állítható) |
| Jellemző **időpontszám** / program | **3–5** → a publikus **gomblista** megfelelő (nem kell legördülő) |
| **Ár megjelenítése** a foglalási oldalon | Fejlesztőre bízva → **első verzió: „…Ft-tól" a kártyán + konkrét ár az időpont-gombokon** |
| **Elmaradt** állapot időpontonként? | **KELL** — időpontonkénti `elmaradt`. Elmaradáskor az **adott időpont foglalóinak** elmaradó e-mail (`program_elmarad` sablon) megy |
| **Foglalás áthelyezése** másik időpontra | Admin **átteheti** ugyanazon program másik időpontjára, **ha az ár azonos**. Eltérő árnál a vendégnek **újra kell foglalnia**. |
| **Nincs** meghirdetett (jövőbeli aktív) időpont | A program **„Hamarosan"** jelzéssel marad a weblapon |
| **Előadó / programvezető** mező | **KELL** — a **programhoz** (workshop) tartozó `eloado` szöveges mező, akár több névvel (vesszővel). A weblapon „**Előadó: Szabó Zoltán, Nagy Andrea**" formában jelenik meg |

### A foglalás-áthelyezés használati esetei
1. **A szervező lemond egy időpontot**, és a vendégeknek másik időpontot ajánl fel.
2. **A vendég jelzi, hogy nem jó neki az időpont** → az admin átteszi máskorra.

Mindkettő csak **azonos ár** esetén megy egy kattintással; eltérő árnál új foglalás kell.

---

## 4) Végleges adatmodell

```
workshops (program – KÖZÖS adatok, minden időpontra érvényesek)
  id            uuid PK
  cim           text        not null       -- a program egészéhez tartozik
  rovid_leiras  text                        -- a program egészéhez tartozik
  leiras        text                        -- a program egészéhez tartozik
  eloado        text                        -- előadó(k); akár több név vesszővel
  varhato_idotartam text
  foto_url      text                        -- a program egészéhez tartozik
  statusz       text  in ('aktiv','hamarosan')   -- 'hamarosan' = szándékos teaser
  archivalt     boolean
  created_at    timestamptz

  -- IDŐPONTONKÉNT változó (az idopontok táblában): dátum, ár, kedvezményes ár,
  -- létszám, elmaradt-állapot. Minden más a programhoz kötődik.

idopontok (egy alkalom – ÚJ tábla)
  id            uuid PK
  workshop_id   uuid  → workshops(id) on delete cascade
  idopont       timestamptz not null
  ar            integer                      -- Ft, aktív időpontnál kötelező
  kedvezmenyes_ar integer                    -- opcionális; < ar
  max_letszam   integer     not null  (>0)
  statusz       text  in ('aktiv','elmaradt') default 'aktiv'
  created_at    timestamptz

bookings (foglalás – az IDŐPONTRA hivatkozik)
  ...           (változatlan mezők)
  idopont_id    uuid  → idopontok(id)         -- a workshop_id HELYETT
```

**Megjelenítési szabály (publikus):** egy program **időpont-gombokat** mutat, ha van
legalább egy **jövőbeli, aktív** időpontja; különben **„Hamarosan"** kártyaként jelenik
meg (gombok nélkül). A múltbeli időpontok gombja „Lezárult"; a betelt „Betelt"; az
elmaradt nem foglalható. *(A csak múltbeli időpontokkal rendelkező, lezárult programokat
az admin archiválja — ez a meglévő folyamat.)*

---

## 5) Az árazás következményei (a döntésekből)

- A **kártya** tetején „**…Ft-tól**" (a legolcsóbb aktív, jövőbeli időpont ára).
- Az **időpont-gombon**: dátum · konkrét ár · szabad hely.
- **Admin program-űrlap:** az ár/kedvezményes ár/létszám **időpontonként** adható meg
  (nem a program szintjén).
- **Foglalás-áthelyezés:** a cél-időpontok listája a **azonos árú** időpontokra szűrve
  (és van szabad hely). Eltérő árnál nincs áthelyezés → új foglalás.

---

## 6) A megvalósítás fázisai

Fázisonként haladunk, minden fázis végén megállunk ellenőrizni.

- **1. fázis — DB**
  - Új `idopontok` tábla (ár, kedvezményes ár, létszám, státusz).
  - `bookings.workshop_id` → `bookings.idopont_id`.
  - `foglalt_helyek(p_idopont uuid)` — időpontra számol.
  - `programok` nézet = program × időpont (LEFT JOIN, hogy az időpont nélküli
    „hamarosan" program is látszódjon) + `szabad_helyek`.
  - Túlfoglalás-trigger: az időpont `max_letszam`/`statusz`/`idopont` alapján.
  - RLS: `idopontok` olvasható bárkinek, írás csak adminnak.
  - Szállítás: `db/07-tobb-idopont.sql` (inkrementális, `ALTER`/`DROP`) **és** a
    `db/01-schema.sql` frissítése (teljes igazságforrás).
  - Átnézendő (szintén `workshop_id`/`idopont`-ra épül):
    `db/03-auto-visszaigazolo-trigger.sql`, `db/04-emlekezteto-cron.sql`.

- **2. fázis — publikus** (`web/js/app.js` + `web/index.html`)
  - Programonkénti csoportosítás; időpont-gombok (dátum · ár · szabad hely).
  - Kártyán „…Ft-tól"; „Hamarosan", ha nincs jövőbeli aktív időpont.
  - Kártyán **„Előadó: …"** megjelenítés (ha van kitöltve).
  - Foglalás a kiválasztott `idopont_id`-ra.

- **3. fázis — admin** (`web/admin/admin.js` + `web/admin/index.html`)
  - Program-lista és naptár **időpontonként** külön sor.
  - Program-szerkesztő: program-szintű mezők (cím, leírások, **előadó**, kép) +
    **időpontok kezelése** (hozzáad/módosít/töröl), időpontonként ár/kedvezményes
    ár/létszám; időpont **lemondása** (`elmaradt`) → az adott időpont foglalóinak
    `program_elmarad` e-mail.
  - **Foglalás-áthelyezés** másik időpontra (azonos ár + szabad hely szűréssel).
  - Foglalás-szűrő, export a `bookings → idopontok → workshops` join mentén.

---

## 7) Érintett fájlok

| Réteg | Fájl(ok) |
|---|---|
| DB (séma) | `db/01-schema.sql`, `db/07-tobb-idopont.sql` (új) |
| DB (kapcsolódó) | `db/03-auto-visszaigazolo-trigger.sql`, `db/04-emlekezteto-cron.sql` |
| Publikus | `web/js/app.js`, `web/index.html` |
| Admin | `web/admin/admin.js`, `web/admin/index.html` |
| E-mail | a `{idopont}` mező a foglalás időpontjából jön; a `program_elmarad` sablon
           marad, csak most időpont-szinten sül el |

---

## 8) Nyitott pontok

Nincs több nyitott üzleti kérdés. A megjelenítési „…Ft-tól" verzió az első kör; ha a
megrendelő később a gombonkénti árat preferálja, az kis frontend-módosítás.
