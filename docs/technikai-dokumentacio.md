# Kemence Akadémia — Technikai dokumentáció

> Ez a fájl **mindig a jelenlegi, tényleges állapotot** írja le (nem a tervet — az a `fejlesztesi-terv.md`).
> Utolsó frissítés: 2026-07-29.

## 1. Architektúra

- **Frontend:** statikus HTML/CSS/JS (nincs build lépés, nincs framework). A böngésző a `@supabase/supabase-js` CDN-klienssel beszél a Supabase-szel.
- **Backend:** **Supabase** (PostgreSQL + Auth + RLS + Storage + — később — Edge Functions).
- **Hoszting:** fejlesztéskor helyi Python szerver (localhost:5500); élesben **Hostinger** (statikus fájlok). Az adat mindig a Supabase-ből jön.
- **Tulajdon:** a Supabase-projekt az ügyfélé, a fejlesztő meghívott közreműködő. Demó a fejlesztő saját fiókján.

## 2. Projektstruktúra

```
db/                         SQL — adatbázis
  01-schema.sql             A TELJES, mindig naprakész séma (üres telepítéshez elég ez)
  02-seed-teszt.sql         Teszt programok (ideiglenes)
  03-migracio-infosav.sql   Migráció: settings.foglalas_infosav
  04-seed-foglalasok-teszt.sql  ÖNÁLLÓ demó-adat: MINDENT töröl + azonosítót nulláz, majd 8 programot (2 múltbéli, 4 jövőbeli, 2 hamarosan) és ~21 foglalást visz fel időrendben. Kiváltja a 02-t.
  05-migracio-email-sablonok.sql Migráció: azonosito + email_sablonok
  06-migracio-email-log.sql Migráció: email_log + demó napló
  07-migracio-azonosito-formatum.sql Migráció: azonosító előtag/kezdő + belső sorszám 1-től
  08-migracio-sablonok-bovites.sql Migráció: visszaigazolás + csapat-értesítő sablon
  09-migracio-storage-fotok.sql Migráció: Storage bucket a program-fotókhoz
  10-migracio-archivalas.sql Migráció: program-archiválás + program_elmarad sablon
  11-migracio-elmaradt-programallapot.sql Migráció: az "elmaradt" a PROGRAM állapota (nem a foglalásé)
  12-migracio-multbeli-foglalas-tiltas.sql Migráció: publikus (anon) foglalás tiltása MÚLTBÉLI eseményre (a mai nap még OK)
  13-migracio-emlekezteto-sablon.sql Migráció: „emlékeztető" e-mail sablon (a program előtti napon, a vendégnek)
web/                        Frontend (ezt szolgálja ki a szerver / Hostinger)
  index.html                Publikus oldal (programok + foglalás)
  css/style.css             Publikus stílus (sötét, "parázs" paletta)
  css/dialog.css            Közös felugró ablak stílusa
  js/config.js              Supabase Project URL + anon kulcs (publikus, RLS véd)
  js/dialog.js              Saját felugró ablak (alert/confirm helyett)
  js/app.js                 Publikus logika (programok, foglalási űrlap)
  admin/index.html          Admin oldal (belépés + fülek)
  admin/admin.css           Admin stílus
  admin/admin.js            Admin logika
supabase/functions/send-email/index.ts  E-mail küldő Edge Function (Deno + Gmail SMTP → email_log). Beállítás: docs/email-kuldes-setup.md
docs/                       Élő dokumentáció (ez a mappa)
fejlesztesi-terv.md         A terv / roadmap
foglalasi-rendszer-terv.html  Ügyfél-facing áttekintő (bemutató)
felmeres-kerdessor.html/.pdf  Az ügyféligény-felmérés
start-szerver.bat           Helyi szerver indító (localhost:5500)
```

## 3. Adatbázis

### Táblák

**`workshops`** — programok
`id` (uuid, PK) · `cim` · `leiras` · `ar` · `kedvezmenyes_ar` · `idopont` (timestamptz) · `varhato_idotartam` · `max_letszam` · `foto_url` · `statusz` (`aktiv`/`hamarosan`/`elmaradt`) · `archivalt` (bool) · `created_at`
Megszorítások: akciós ár < alap ár; `aktiv` státusznál kötelező ár+időpont+létszám; létszám>0.

**`bookings`** — foglalások
`id` (uuid, PK) · `azonosito` (bigint identity, **1-től**) · `workshop_id` (FK→workshops, `on delete restrict`) · `nev` · `email` · `telefon` · `letszam` (>0) · `megjegyzes` · `statusz` (`jovahagyasra_var`/`jovahagyott`/`elutasitott`/`lemondott`) · `created_at`
Indexek: workshop_id, statusz, azonosito (egyedi).

**`settings`** — egysoros (id=1)
`levelezesi_email` (a **csapat** címe — ide megy a `csapat_ertesito`; NEM a feladó, az a `GMAIL_USER` secret) · `foglalas_infosav` · `azonosito_elotag` (≤2 kar) · `azonosito_kezdo` (1–999) · `updated_at`

**`email_sablonok`** — e-mail sablonok
`tipus` (PK: `visszaigazolas`/`csapat_ertesito`/`jovahagyas`/`elutasitas`/`lemondas`/`program_elmarad`/`emlekezteto`) · `targy` · `torzs` · `updated_at`
Behelyettesíthető mezők: `{nev} {email} {telefon} {program} {idopont} {letszam} {azonosito}`.

**`email_log`** — kiküldött levelek naplója (tartalom nélkül)
`id` (bigint, PK) · `booking_id` (FK→bookings, `on delete cascade`) · `tipus` · `cimzett` · `elkuldve`

### Nézet, függvények, trigger
- **`programok`** (nézet): workshops mezői + `szabad_helyek` (kiszámítva). Ezt olvassa a publikus oldal.
- **`foglalt_helyek(uuid)`** (függvény, `security definer`): egy program foglalt helyeinek száma (a `jovahagyasra_var` + `jovahagyott` foglalások létszám-összege). Anon is hívhatja, de a foglalási sorokat nem látja.
- **`ellenoriz_szabad_hely()`** + **`trg_szabad_hely`** trigger (bookings, before insert/update): túlfoglalás elleni védelem; nem-aktív programra nem enged foglalni; a **publikus (anon) foglalást múltbéli eseményre elutasítja** (a mai nap még OK; az admin/seed rögzíthet historikusat).

### Szabad helyek és azonosító képletei
- **Szabad helyek:** `max_letszam − (jovahagyasra_var + jovahagyott létszámok)`. Az `elutasitott`/`lemondott` felszabadít.
- **Megjelenített azonosító:** `azonosito_elotag + (bookings.azonosito + azonosito_kezdo − 1)`. Alap: `F-` + 100 → `F-100`.

### Storage
- **`program-fotok`** bucket (publikus olvasás, admin írás) — ide töltődnek a program-fotók; a `workshops.foto_url` a publikus URL-t tárolja.

### Biztonság (RLS)
| Tábla | Publikus (anon) | Admin (authenticated) |
|---|---|---|
| workshops | olvas | mindent |
| bookings | csak beküld (statusz='jovahagyasra_var') | olvas/módosít/töröl |
| settings | olvas | mindent |
| email_sablonok | — | mindent |
| email_log | — | olvas (írás service-role-lal) |

Egyetlen admin fiók (Supabase Auth), **önregisztráció nincs** — a fiókot a gépházban hozzuk létre. Jelenleg minden bejelentkezett = admin.

## 4. Konvenciók

- **`db/01-schema.sql` az egyetlen igazságforrás** — mindig a teljes, friss sémát tartalmazza; üres/éles telepítéshez elég ezt lefuttatni. A `0X-migracio-*.sql` fájlok a már futó fejlesztői DB-t frissítik.
- **Nincs böngésző-`alert`/`confirm`/`prompt`** — minden felugró a saját `web/js/dialog.js` (`dialog.megerosit` / `dialog.uzen`).
- **Nincs placeholder ("árnyékszöveg")** a beviteli mezőkben.
- **Design:** v2 minta elrendezése + v1 minta sötét parázs-palettája; a foglalás/admin naptár-jellegű. Betűk: Fraunces + Hanken Grotesk + Space Mono.
- **Fejlesztés `http://localhost`-ról** (nem `file://`) — az auth a böngésző tárolóját használja, ami `file://` alól nem működik jól.

## 5. Futtatás

- **Helyi szerver:** `start-szerver.bat` (dupla katt) → `http://localhost:5500/` (publikus), `/admin/` (admin).
- **Adatbázis:** a `db/*.sql` fájlokat a Supabase **SQL Editor**ban futtatjuk. Sorrend friss dev DB-hez: 01 → (04 demó-adat) → 03, 05, 06, 07, 08, 09, 10, 11, 12, 13 migrációk. Éles/üres telepítés: elég a **01** (mindig a teljes, friss séma). A legutóbbi migrációk: `12` (múltbéli publikus foglalás tiltása), `13` (emlékeztető sablon).
- **Config:** a `web/js/config.js`-be kell a Supabase **Project URL** és **anon** kulcs (Settings → API).
